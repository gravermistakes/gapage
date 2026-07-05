#!/usr/bin/env perl
# rbac_flagger.pl — Flag self-modifying workload RBAC
# Doc 5 principle: agents should not have permissions to resemble their orchestrator
# Output: list of ServiceAccounts whose roles permit them to patch their own
# Deployment, modify their own Lease, or read self-describing state.
# SPDX-License-Identifier: GPL-3.0-or-later
use strict; use warnings;
use Getopt::Long;
use JSON::PP;

my %opt = ();
GetOptions(\%opt, 'roles=s', 'bindings=s', 'serviceaccounts=s', 'out=s')
    or die "Usage: $0 --roles roles.json --bindings rolebindings.json --serviceaccounts sa.json\n";

sub load_json {
    my $path = shift;
    open my $fh, '<', $path or die "Cannot open $path: $!\n";
    local $/; my $raw = <$fh>; close $fh;
    my $data = decode_json($raw);
    return ref($data) eq 'HASH' && $data->{items} ? $data->{items} : $data;
}

# Self-referential operations - these are the dangerous capabilities
my %self_ref_ops = (
    'leases.coordination.k8s.io'    => [qw(create update patch)],
    'deployments.apps'              => [qw(patch update)],
    'pods'                          => [qw(patch update create)],
    'configmaps'                    => [qw(patch update create)],
    'secrets'                       => [qw(get list)],
    'serviceaccounts/token'         => [qw(create)],
    'rolebindings.rbac.authorization.k8s.io' => [qw(create patch)],
    'clusterrolebindings.rbac.authorization.k8s.io' => [qw(create patch)],
);

my $roles = $opt{roles} ? load_json($opt{roles}) : [];
my $bindings = $opt{bindings} ? load_json($opt{bindings}) : [];

my $out_fh;
if ($opt{out}) { open $out_fh, '>', $opt{out} or die; } else { $out_fh = \*STDOUT; }

print $out_fh "RBAC_SELF_MODIFY_FLAGGER\n";
print $out_fh "=" x 60 . "\n";

# Build role -> dangerous-rules index
my %role_risk;
for my $role (@$roles) {
    my $name = $role->{metadata}{name};
    my $ns = $role->{metadata}{namespace} // '*cluster*';
    my $key = "$ns/$name";
    next unless $role->{rules};

    for my $rule (@{$role->{rules}}) {
        my $verbs = $rule->{verbs} // [];
        my $resources = $rule->{resources} // [];
        my $apigroups = $rule->{apiGroups} // [''];

        for my $resource (@$resources) {
            for my $apigroup (@$apigroups) {
                my $full = $apigroup ? "$resource.$apigroup" : $resource;
                if (exists $self_ref_ops{$full}) {
                    for my $verb (@$verbs) {
                        if ($verb eq '*' || grep { $_ eq $verb } @{$self_ref_ops{$full}}) {
                            push @{$role_risk{$key}}, {
                                resource => $full,
                                verb => $verb,
                            };
                        }
                    }
                }
            }
        }
    }
}

# Walk bindings - which ServiceAccounts get which dangerous roles?
my %sa_risk;
for my $rb (@$bindings) {
    my $role_name = $rb->{roleRef}{name};
    my $role_ns = $rb->{metadata}{namespace} // '*cluster*';
    my $role_key = "$role_ns/$role_name";
    next unless $role_risk{$role_key};

    for my $subject (@{$rb->{subjects} // []}) {
        next unless ($subject->{kind} // '') eq 'ServiceAccount';
        my $sa_key = ($subject->{namespace} // '?') . "/" . ($subject->{name} // '?');
        push @{$sa_risk{$sa_key}}, {
            role => $role_key,
            risks => $role_risk{$role_key},
        };
    }
}

# Report
if (%sa_risk) {
    print $out_fh "\n*** SELF-MODIFYING SERVICE ACCOUNTS ***\n";
    for my $sa (sort keys %sa_risk) {
        print $out_fh "\nSA: $sa\n";
        for my $r (@{$sa_risk{$sa}}) {
            print $out_fh "  via role: $r->{role}\n";
            for my $risk (@{$r->{risks}}) {
                printf $out_fh "    - %s %s\n", $risk->{verb}, $risk->{resource};
            }
        }
        print $out_fh "  → REVIEW: workload with this SA can modify its own infrastructure.\n";
        print $out_fh "    Consider break-glass identity for these operations.\n";
    }
} else {
    print $out_fh "\nNo self-modifying ServiceAccount RBAC detected.\n";
}

printf $out_fh "\nSUMMARY: %d roles flagged, %d service accounts at risk.\n",
    scalar(keys %role_risk), scalar(keys %sa_risk);
close $out_fh if $opt{out};

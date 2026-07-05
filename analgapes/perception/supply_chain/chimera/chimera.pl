#!/usr/bin/env perl
# Chimera – CVE feed aggregator
# Copyright (C) 2026 Anja Evermoor
# GNU GPL v3.0 or later
#
# Queries NVD and OSV for known CVEs affecting a given library.
# Falls back gracefully if network is unavailable.

use strict;
use warnings;
use File::Basename;

# Check for JSON module availability
my $HAS_JSON = eval { require JSON; JSON->import(); 1 };
my $HAS_LWP  = eval { require LWP::UserAgent; 1 };

my $library   = $ARGV[0] or die "Usage: chimera.pl <library_name> [--output <file>]\n";
my $output_file = "";
for my $i (0..$#ARGV) {
    if ($ARGV[$i] eq "--output" && defined $ARGV[$i+1]) {
        $output_file = $ARGV[$i+1];
    }
}

# Normalize library name: strip lib prefix, .so suffix, version
(my $search_term = $library) =~ s/^lib//;
$search_term =~ s/\.so[\d.]*$//;

my @cves;

# === NVD API (v2.0, no key required for basic queries) ===
if ($HAS_JSON && $HAS_LWP) {
    my $ua = LWP::UserAgent->new(
        timeout => 30,
        agent   => "Phoenix-Chimera/1.0",
    );

    # NVD search
    my $nvd_url = "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=$search_term&resultsPerPage=25";
    warn "[Chimera] Querying NVD for: $search_term\n";
    my $resp = $ua->get($nvd_url);

    if ($resp->is_success) {
        my $data = JSON::decode_json($resp->decoded_content);
        my $vulns = $data->{vulnerabilities} || [];
        for my $vuln (@$vulns) {
            my $cve = $vuln->{cve};
            my $id = $cve->{id} || "UNKNOWN";

            # Extract description
            my $desc = "";
            for my $d (@{$cve->{descriptions} || []}) {
                if ($d->{lang} eq "en") {
                    $desc = $d->{value};
                    last;
                }
            }

            # Extract CVSS score
            my $cvss = "N/A";
            my $severity = "UNKNOWN";
            if (my $m31 = $cve->{metrics}{cvssMetricV31}) {
                if (ref $m31 eq 'ARRAY' && @$m31) {
                    $cvss = $m31->[0]{cvssData}{baseScore} // "N/A";
                    $severity = $m31->[0]{cvssData}{baseSeverity} // "UNKNOWN";
                }
            } elsif (my $m2 = $cve->{metrics}{cvssMetricV2}) {
                if (ref $m2 eq 'ARRAY' && @$m2) {
                    $cvss = $m2->[0]{cvssData}{baseScore} // "N/A";
                    $severity = $m2->[0]{baseSeverity} // "UNKNOWN";
                }
            }

            # Extract affected versions from CPE matches
            my @affected_versions;
            for my $config (@{$cve->{configurations} || []}) {
                for my $node (@{$config->{nodes} || []}) {
                    for my $match (@{$node->{cpeMatch} || []}) {
                        if ($match->{vulnerable}) {
                            my $vs = $match->{versionStartIncluding} // "";
                            my $ve = $match->{versionEndExcluding} // $match->{versionEndIncluding} // "";
                            push @affected_versions, "$vs-$ve" if $vs || $ve;
                        }
                    }
                }
            }

            # Extract known vulnerable functions from description
            my @vuln_functions;
            while ($desc =~ /\b([a-z_][a-z0-9_]*)\s*\(\s*\)/gi) {
                push @vuln_functions, $1;
            }

            push @cves, {
                id               => $id,
                source           => "NVD",
                description      => $desc,
                cvss             => $cvss,
                severity         => $severity,
                affected_versions => \@affected_versions,
                vuln_functions   => \@vuln_functions,
                published        => $cve->{published} // "",
            };
        }
        warn "[Chimera] NVD returned " . scalar(@$vulns) . " results for $search_term\n";
    } else {
        warn "[Chimera] NVD query failed: " . $resp->status_line . "\n";
    }

    # === OSV API ===
    my $osv_url = "https://api.osv.dev/v1/query";
    my $osv_body = JSON::encode_json({
        package => {
            name      => $search_term,
            ecosystem => "OSS-Fuzz",
        }
    });
    warn "[Chimera] Querying OSV for: $search_term\n";
    my $osv_resp = $ua->post($osv_url,
        'Content-Type' => 'application/json',
        Content        => $osv_body,
    );

    if ($osv_resp->is_success) {
        my $osv_data = JSON::decode_json($osv_resp->decoded_content);
        my $osv_vulns = $osv_data->{vulns} || [];
        for my $v (@$osv_vulns) {
            # Skip if already have this CVE from NVD
            my @aliases = @{$v->{aliases} || []};
            my $cve_id = "";
            for my $a (@aliases) {
                if ($a =~ /^CVE-/) { $cve_id = $a; last; }
            }
            $cve_id ||= $v->{id} || "OSV-UNKNOWN";
            next if grep { $_->{id} eq $cve_id } @cves;

            push @cves, {
                id               => $cve_id,
                source           => "OSV",
                description      => $v->{summary} // $v->{details} // "",
                cvss             => "N/A",
                severity         => "UNKNOWN",
                affected_versions => [],
                vuln_functions   => [],
                published        => $v->{published} // "",
            };
        }
        warn "[Chimera] OSV returned " . scalar(@$osv_vulns) . " results for $search_term\n";
    } else {
        warn "[Chimera] OSV query failed: " . $osv_resp->status_line . "\n";
    }
} else {
    warn "[Chimera] WARNING: JSON or LWP::UserAgent not available\n";
    warn "[Chimera] Falling back to curl-based NVD query\n";

    my $nvd_raw = `curl -s --max-time 30 "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=$search_term&resultsPerPage=10" 2>/dev/null`;
    if ($nvd_raw && $nvd_raw =~ /\{/) {
        # Minimal extraction without JSON module
        while ($nvd_raw =~ /"id"\s*:\s*"(CVE-[\d-]+)"/g) {
            push @cves, {
                id          => $1,
                source      => "NVD-curl",
                description => "(parsed without JSON module)",
                cvss        => "N/A",
                severity    => "UNKNOWN",
                affected_versions => [],
                vuln_functions   => [],
                published   => "",
            };
        }
        warn "[Chimera] curl fallback found " . scalar(@cves) . " CVE IDs\n";
    }
}

# === Output ===
my $json_out;
if ($HAS_JSON) {
    $json_out = JSON::encode_json(\@cves);
} else {
    # Manual JSON construction
    my @items;
    for my $c (@cves) {
        my $desc = $c->{description};
        $desc =~ s/"/\\"/g;
        $desc =~ s/\n/\\n/g;
        push @items, sprintf(
            '{"id":"%s","source":"%s","cvss":"%s","severity":"%s","description":"%s"}',
            $c->{id}, $c->{source}, $c->{cvss}, $c->{severity}, $desc
        );
    }
    $json_out = "[" . join(",", @items) . "]";
}

if ($output_file) {
    open(my $fh, '>', $output_file) or die "Cannot write $output_file: $!\n";
    print $fh $json_out, "\n";
    close $fh;
    warn "[Chimera] Output written to $output_file\n";
} else {
    print $json_out, "\n";
}

exit 0;

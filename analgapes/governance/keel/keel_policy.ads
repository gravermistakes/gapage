-- SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
-- analgapes :: governance/keel/keel_policy.ads
--
-- KEEL — the governance rudder. Policy enforcement as provable Ada/SPARK
-- contracts, NOT democratic process. No voting, no quorum, no proposals.
-- KEEL answers four questions before any action is permitted:
--   1. Is the target in authorized scope?        (In_Scope)
--   2. Does the operation honor the ESL license?  (ESL_Compliant)
--   3. Is the witness chain intact?               (Chain_Integrity)
--   4. Is the action embedded-agency-safe?        (Agency_Safe)
-- Disclosure timing is NOT here — it is per-engagement, set by program terms.

with Interfaces.C;

package KEEL_Policy
  with SPARK_Mode => On
is
   type Authorization is (Denied, Permitted);

   -- A scope assertion is the set of facts KEEL checks an action against.
   -- All fields operator-supplied; KEEL never fabricates authorization.
   type Scope_Assertion is record
      Target_In_Program : Boolean;   -- target named in the engagement scope
      Written_Auth      : Boolean;   -- written authorization on file
      Esl_Attribution   : Boolean;   -- ESL attribution JSON present + valid
      Esl_Sharealike    : Boolean;   -- derivative honors ShareAlike
      Chain_Tip_Valid   : Boolean;   -- witness chain tip verifies
      Goodhart_Guarded  : Boolean;   -- metric not being gamed (embedded agency)
      Corrigible        : Boolean;   -- action remains interruptible/overridable
   end record;

   -- An action is in scope iff named in the program AND backed by written auth.
   function In_Scope (S : Scope_Assertion) return Boolean is
     (S.Target_In_Program and then S.Written_Auth);

   -- ESL compliance: attribution present AND sharealike honored.
   function ESL_Compliant (S : Scope_Assertion) return Boolean is
     (S.Esl_Attribution and then S.Esl_Sharealike);

   -- Chain integrity: the witness tip must verify.
   function Chain_Integrity (S : Scope_Assertion) return Boolean is
     (S.Chain_Tip_Valid);

   -- Embedded-agency safety: not gaming the metric, and stays corrigible.
   function Agency_Safe (S : Scope_Assertion) return Boolean is
     (S.Goodhart_Guarded and then S.Corrigible);

   -- The gate. Permitted IFF all four hold. This is the 断 (decide/gate)
   -- edge in the witness chain: a PERMITTED decision is recorded; a DENIED
   -- one is recorded as edge "断−" (gate failed).
   function Gate (S : Scope_Assertion) return Authorization
     with Post => (Gate'Result = Permitted) =
                  (In_Scope (S) and then ESL_Compliant (S)
                   and then Chain_Integrity (S) and then Agency_Safe (S));

end KEEL_Policy;

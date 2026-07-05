-- SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
-- analgapes :: governance/keel/keel_policy.adb

package body KEEL_Policy
  with SPARK_Mode => On
is
   function Gate (S : Scope_Assertion) return Authorization is
   begin
      if In_Scope (S) and then ESL_Compliant (S)
        and then Chain_Integrity (S) and then Agency_Safe (S)
      then
         return Permitted;
      else
         return Denied;
      end if;
   end Gate;
end KEEL_Policy;

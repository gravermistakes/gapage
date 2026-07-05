-- SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
-- analgapes :: governance/keel/test_keel.adb
--
-- Verifies: (1) Gate is Permitted IFF all four predicates hold;
--           (2) the Ada->C seal matches the C backbone (printed for
--               cross-check against openssl in the Makefile).

with Ada.Text_IO; use Ada.Text_IO;
with KEEL_Policy;  use KEEL_Policy;
with KEEL_Seal;

procedure Test_KEEL is
   Fails : Natural := 0;

   procedure Check (Cond : Boolean; Msg : String) is
   begin
      if Cond then Put_Line ("PASS: " & Msg);
      else Put_Line ("FAIL: " & Msg); Fails := Fails + 1;
      end if;
   end Check;

   All_True : constant Scope_Assertion :=
     (Target_In_Program => True, Written_Auth => True,
      Esl_Attribution => True, Esl_Sharealike => True,
      Chain_Tip_Valid => True, Goodhart_Guarded => True, Corrigible => True);
begin
   -- Gate: all true => Permitted
   Check (Gate (All_True) = Permitted, "gate permits when all four hold");

   -- Each single failure => Denied
   declare S : Scope_Assertion := All_True; begin
      S.Written_Auth := False;
      Check (Gate (S) = Denied, "no written auth => denied (out of scope)");
   end;
   declare S : Scope_Assertion := All_True; begin
      S.Esl_Attribution := False;
      Check (Gate (S) = Denied, "no ESL attribution => denied");
   end;
   declare S : Scope_Assertion := All_True; begin
      S.Chain_Tip_Valid := False;
      Check (Gate (S) = Denied, "broken chain tip => denied");
   end;
   declare S : Scope_Assertion := All_True; begin
      S.Corrigible := False;
      Check (Gate (S) = Denied, "non-corrigible action => denied (agency-unsafe)");
   end;
   declare S : Scope_Assertion := All_True; begin
      S.Goodhart_Guarded := False;
      Check (Gate (S) = Denied, "metric-gaming => denied (Goodhart guard)");
   end;

   -- Seal: print digest of "analgapes" for openssl cross-check
   Put_Line ("SEAL analgapes = " & KEEL_Seal.Seal ("analgapes"));

   if Fails = 0 then Put_Line ("ALL KEEL TESTS PASSED");
   else Put_Line ("KEEL FAILURES:" & Natural'Image (Fails)); end if;
end Test_KEEL;

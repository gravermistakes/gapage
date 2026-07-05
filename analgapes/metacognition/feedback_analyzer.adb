-- FEEDBACK ANALYSER – Compare sandbox validation outcome to prediction
-- Checks for canary file (arbitrary write evidence) rather than euid
-- SPDX-License-Identifier: GPL-3.0-or-later
with Ada.Text_IO;    use Ada.Text_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Directories; use Ada.Directories;

procedure Feedback_Analyzer is
   Validation_Log : constant String :=
     (if Argument_Count >= 1 then Argument (1) else "");
   Primitive_File : constant String :=
     (if Argument_Count >= 2 then Argument (2) else "");
   Workspace : constant String :=
     (if Argument_Count >= 3 then Argument (3)
      else "/home/user/A51/avrs-cybernetic");

   Expected_Crash : Boolean := True;
   Got_Crash      : Boolean := False;
   Canary_Present : Boolean := False;
begin
   -- Check canary evidence (confirms write primitive / RCE)
   Canary_Present := Exists (Workspace & "/results/canary_evidence.txt");

   if Primitive_File'Length > 0 and then Exists (Primitive_File) then
      declare
         F    : File_Type;
         Line : String (1 .. 512);
         Last : Natural;
      begin
         Open (F, In_File, Primitive_File);
         while not End_Of_File (F) loop
            Get_Line (F, Line, Last);
            -- padding_oracle or info_leak don't require a crash
            if Line (1 .. Natural'Min (Last, 14)) = "padding_oracle" or else
               Line (1 .. Natural'Min (Last, 9))  = "info_leak"
            then
               Expected_Crash := False;
            end if;
         end loop;
         Close (F);
      exception
         when others => null;
      end;
   end if;

   if Validation_Log'Length > 0 and then Exists (Validation_Log) then
      declare
         F    : File_Type;
         Line : String (1 .. 512);
         Last : Natural;
      begin
         Open (F, In_File, Validation_Log);
         while not End_Of_File (F) loop
            Get_Line (F, Line, Last);
            if Last >= 7 and then Line (1 .. 7) = "SIGSEGV" then
               Got_Crash := True;
            end if;
            if Last >= 6 and then Line (1 .. 6) = "SIGABR" then
               Got_Crash := True;
            end if;
         end loop;
         Close (F);
      exception
         when others => null;
      end;
   end if;

   if Canary_Present then
      Put_Line ("[Feedback] ✓ CANARY: write primitive confirmed. Exploit valid.");
      Set_Exit_Status (0);
   elsif Expected_Crash and Got_Crash then
      Put_Line ("[Feedback] ✓ Crash observed as expected. Primitive correct.");
      Set_Exit_Status (0);
   elsif Expected_Crash and not Got_Crash then
      Put_Line ("[Feedback] FAIL: Expected crash not observed. Retry primitive.");
      Set_Exit_Status (1);
   elsif not Expected_Crash and Got_Crash then
      Put_Line ("[Feedback] UNEXPECTED: Crash without prediction. Escalate.");
      Set_Exit_Status (2);
   else
      Put_Line ("[Feedback] INCONCLUSIVE: No conclusive evidence.");
      Set_Exit_Status (0);
   end if;
end Feedback_Analyzer;

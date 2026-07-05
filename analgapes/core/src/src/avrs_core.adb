-- AVRS v3.0 Cybernetic – Core Loop Body
-- the operator-integrated 13-phase state machine with feedback edges

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Integer_Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Text_IO; use Ada.Strings.Unbounded.Text_IO;
with Ada.Directories; use Ada.Directories;
with Ada.Calendar; use Ada.Calendar;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with Ada.Command_Line; use Ada.Command_Line;

package body Avrs_Core is

   Workspace : constant String := (if Argument_Count >= 1 then Argument(1)
                                    else "/home/user/A51/avrs-cybernetic");

   procedure Shell_Redirect (Cmd : String; Out_File : String; Ret : out Integer) is
      Full_Cmd : constant String := Cmd & " > " & Out_File & " 2>&1";
      Status : aliased Integer;
      Args : Argument_List := (1 => new String'("-c"), 2 => new String'(Full_Cmd));
   begin
      Status := Spawn (Program_Name => "/bin/bash", Args => Args);
      Ret := Status;
   end Shell_Redirect;

   procedure Shell_Out (Cmd : String; Ret : out Integer; Out_Str : out Unbounded_String) is
      Tmp_File : constant String := "/tmp/avrs_out_" & Integer'Image(Integer(Ada.Calendar.Clock - Ada.Calendar.Time_Of(1970,1,1))) & ".tmp";
      Status : aliased Integer;
      Args : Argument_List := (1 => new String'("-c"),
                                2 => new String'(Cmd & " > " & Tmp_File & " 2>&1"));
   begin
      Out_Str := Null_Unbounded_String;
      Status := Spawn (Program_Name => "/bin/bash", Args => Args);
      Ret := Status;
      declare
         F : File_Type;
      begin
         if Exists (Tmp_File) then
            Open (F, In_File, Tmp_File);
            while not End_Of_File (F) loop
               Append (Out_Str, String'(Get_Line (F) & ASCII.LF));
            end loop;
            Close (F);
            Delete_File (Tmp_File);
         end if;
      exception
         when others => null;
      end;
   end Shell_Out;

   function Check_Cortex_Override (Path : String) return Boolean is
      Full_Path : constant String := Workspace & "/" & Path;
   begin
      return Exists (Full_Path) and then Size (Full_Path) > 0;
   end Check_Cortex_Override;

   function Read_Cortex_File (Path : String) return Unbounded_String is
      F : File_Type;
      Content : Unbounded_String := Null_Unbounded_String;
   begin
      Open (F, In_File, Workspace & "/" & Path);
      while not End_Of_File (F) loop
         Append (Content, String'(Get_Line (F) & ASCII.LF));
      end loop;
      Close (F);
      return Content;
   exception
      when others => return Null_Unbounded_String;
   end Read_Cortex_File;

   procedure Await_Operator (Hint : String) is
      Dummy : String (1 .. 256);
      Last  : Natural;
   begin
      Put_Line ("[AVRS] ⏸ Awaiting the operator strategic input: " & Hint);
      Put_Line ("[AVRS] Write to " & Workspace & "/kerebral/ and press return...");
      Get_Line (Dummy, Last);
   end Await_Operator;

   procedure Run_Phase (P : in Phase; Result : out Phase_Result) is
      Ret : Integer := 0;
      Out_Str : Unbounded_String := Null_Unbounded_String;
   begin
      Result := (Success => False, Exit_Code => -1,
                 Stdout => Null_Unbounded_String, Stderr => Null_Unbounded_String,
                 Duration => 0.0);

      case P is
         when Bootstrap =>
            Shell_Out ("cd " & Workspace & " && bash boot/init.sh", Ret, Out_Str);
            Result.Success := Ret = 0;
            Result.Exit_Code := Ret;
            Result.Stdout := Out_Str;

         when Env_Scan =>
            Shell_Redirect ("file " & Workspace & "/../target_binary",
                            Workspace & "/results/env_scan_file.txt", Ret);
            Shell_Redirect ("readelf -a " & Workspace & "/../target_binary",
                            Workspace & "/results/env_scan_readelf.txt", Ret);
            Shell_Redirect ("strings " & Workspace & "/../target_binary",
                            Workspace & "/results/env_scan_strings.txt", Ret);
            Result.Success := Ret = 0;
            Result.Exit_Code := Ret;

         when Static_Lift =>
            if Exists (Workspace & "/perception/static/obj/sledge") then
               Shell_Redirect (Workspace & "/perception/static/obj/sledge --lift " &
                               Workspace & "/../target_binary --output " &
                               Workspace & "/data/memory/lift_proofs.txt",
                               Workspace & "/results/sledge.log", Ret);
               if Ret /= 0 then
                  Shell_Redirect ("objdump -d -M intel " & Workspace & "/../target_binary",
                                  Workspace & "/data/memory/disassembly.txt", Ret);
                  Put_Line ("[AVRS] SLEDGE lift failed. Fell back to objdump.");
               end if;
            else
               Shell_Redirect ("objdump -d -M intel " & Workspace & "/../target_binary",
                               Workspace & "/data/memory/disassembly.txt", Ret);
            end if;
            Result.Success := Ret = 0;
            Result.Exit_Code := Ret;

         when Cap_Model =>
            Shell_Out ("cd " & Workspace & " && " &
                       (if Exists (Workspace & "/cognition/capability_graph/obj/cap_graph")
                        then "./cognition/capability_graph/obj/cap_graph " & Workspace & "/../target_binary"
                        else "echo '[CAP] Stub: capability graph not built'"),
                       Ret, Out_Str);
            Result.Success := Ret = 0;
            Result.Stdout := Out_Str;

         when Taint_Flow =>
            if Exists (Workspace & "/cognition/ghost/ghost_bin") then
               Shell_Redirect (Workspace & "/cognition/ghost/ghost_bin " &
                               Workspace & "/data/memory/disassembly.txt",
                               Workspace & "/results/ghost_taint.log", Ret);
            else
               Put_Line ("[AVRS] Ghost not built; skipping taint phase.");
               Ret := 0;
            end if;
            Result.Success := Ret = 0;

         when Dyn_Conform =>
            if Exists (Workspace & "/perception/dynamic/conformance_driver") then
               Shell_Redirect (Workspace & "/perception/dynamic/conformance_driver " &
                               Workspace & "/../target_binary 500",
                               Workspace & "/results/conformance.log", Ret);
            else
               Put_Line ("[AVRS] Conformance driver not built; GDB-only dynamic test.");
               Shell_Redirect ("echo 'run < /dev/urandom' | gdb -batch " &
                               "-ex 'file " & Workspace & "/../target_binary' " &
                               "-ex 'run < /dev/urandom' -ex 'info registers' 2>&1",
                               Workspace & "/results/gdb_crash.log", Ret);
            end if;
            Result.Success := True;

         when Side_Channel =>
            if Exists (Workspace & "/perception/sidechannel/hammer.fs") then
               Shell_Redirect ("gforth " & Workspace &
                               "/perception/sidechannel/hammer.fs -e 'self-test bye'",
                               Workspace & "/results/hammer.log", Ret);
            end if;
            if Exists (Workspace & "/perception/sidechannel/witness_bin") then
               Shell_Redirect (Workspace & "/perception/sidechannel/witness_bin 0x400000",
                               Workspace & "/results/witness.log", Ret);
            end if;
            Result.Success := True;

         when Anomaly_Fusion =>
            Shell_Out ("perl " & Workspace & "/cognition/fusion/fusion_engine.pl " &
                       Workspace & "/results/ghost_taint.log " &
                       Workspace & "/results/gdb_crash.log " &
                       Workspace & "/results/witness.log " &
                       Workspace & "/data/memory/disassembly.txt",
                       Ret, Out_Str);
            declare
               F : File_Type;
            begin
               Create (F, Out_File, Workspace & "/data/fusion/report.txt");
               Put_Line (F, To_String (Out_Str));
               Close (F);
            end;
            Result.Success := Ret = 0;
            Result.Stdout := Out_Str;

         when Primitive_Extract =>
            if Check_Cortex_Override ("kerebral/hypothesis.txt") then
               Put_Line ("[AVRS] ✓ Using the operator's hypothesis for primitive extraction.");
               declare
                  Hyp : constant Unbounded_String := Read_Cortex_File ("kerebral/hypothesis.txt");
                  F : File_Type;
               begin
                  Create (F, Out_File, Workspace & "/data/memory/primitive.json");
                  Put_Line (F, To_String (Hyp));
                  Close (F);
                  Result.Success := True;
               end;
            else
               if Exists (Workspace & "/cognition/ghost/logic_bin") then
                  Shell_Redirect (Workspace & "/cognition/ghost/logic_bin " &
                                  Workspace & "/data/fusion/report.txt",
                                  Workspace & "/data/memory/primitive.json", Ret);
               else
                  Put_Line ("[AVRS] Logic engine not built. Awaiting the operator...");
                  Await_Operator ("Primitive extraction needed. Write hypothesis.txt.");
                  if Check_Cortex_Override ("kerebral/hypothesis.txt") then
                     declare
                        Hyp : constant Unbounded_String := Read_Cortex_File ("kerebral/hypothesis.txt");
                        F : File_Type;
                     begin
                        Create (F, Out_File, Workspace & "/data/memory/primitive.json");
                        Put_Line (F, To_String (Hyp));
                        Close (F);
                        Result.Success := True;
                     end;
                  end if;
               end if;
               Result.Success := Ret = 0;
            end if;

         when Payload_Synth =>
            if Check_Cortex_Override ("kerebral/exploit_override.pl") then
               Put_Line ("[AVRS] ✓ Using the operator's exploit payload.");
               Copy_File (Workspace & "/kerebral/exploit_override.pl",
                          Workspace & "/action/exploit_synthesis/payload.pl");
               Result.Success := True;
            else
               Shell_Out ("perl " & Workspace & "/action/exploit_synthesis/payload_gen.pl " &
                          Workspace & "/data/memory/primitive.json " &
                          Workspace & "/../target_binary",
                          Ret, Out_Str);
               Result.Success := Ret = 0;
            end if;

         when Sandbox_Val =>
            declare
               Cmd : constant String :=
                 "bash " & Workspace & "/action/sandbox/sandbox_exec.sh " &
                 Workspace & "/../target_binary " &
                 Workspace & "/action/exploit_synthesis/payload.pl";
            begin
               Shell_Redirect (Cmd, Workspace & "/results/validation.log", Ret);
               Result.Success := True;
               Result.Exit_Code := Ret;
            end;

         when Feedback_Anal =>
            if Check_Cortex_Override ("kerebral/retrain_decision.txt") then
               Put_Line ("[AVRS] ✓ Using the operator's retraining decision.");
               declare
                  Decision : constant Unbounded_String :=
                    Read_Cortex_File ("kerebral/retrain_decision.txt");
               begin
                  if Index (Decision, "RETRY") > 0 then
                     Signal := Retry_Primitive;
                  elsif Index (Decision, "ESCALATE") > 0 then
                     Signal := Escalate;
                  else
                     Signal := None;
                  end if;
               end;
            else
               if Exists (Workspace & "/metacognition/feedback_analyzer") then
                  Shell_Redirect (Workspace & "/metacognition/feedback_analyzer " &
                                  Workspace & "/results/validation.log " &
                                  Workspace & "/data/memory/primitive.json",
                                  Workspace & "/results/feedback.log", Ret);
                  if Ret = 1 then
                     Signal := Retry_Primitive;
                  elsif Ret = 2 then
                     Signal := Escalate;
                  else
                     Signal := None;
                  end if;
               end if;
            end if;
            Result.Success := True;

         when Provenance_Seal =>
            Shell_Out ("cd " & Workspace & " && make -f governance/keel/Makefile all 2>&1",
                       Ret, Out_Str);
            Shell_Out ("cd " & Workspace & " && make -f governance/keel/Makefile witness 2>&1",
                       Ret, Out_Str);
            Shell_Out ("perl " & Workspace & "/governance/report_generator.pl " & Workspace,
                       Ret, Out_Str);
            Result.Success := Ret = 0;
            Result.Stdout := Out_Str;
      end case;
   end Run_Phase;

   procedure Transition (P : Phase; Result : Phase_Result) is
   begin
      case P is
         when Bootstrap        => Current_Phase := Env_Scan;
         when Env_Scan         => Current_Phase := Static_Lift;
         when Static_Lift      => Current_Phase := Cap_Model;
         when Cap_Model        => Current_Phase := Taint_Flow;
         when Taint_Flow       => Current_Phase := Dyn_Conform;
         when Dyn_Conform      => Current_Phase := Side_Channel;
         when Side_Channel     => Current_Phase := Anomaly_Fusion;
         when Anomaly_Fusion   => Current_Phase := Primitive_Extract;
         when Primitive_Extract => Current_Phase := Payload_Synth;
         when Payload_Synth    => Current_Phase := Sandbox_Val;
         when Sandbox_Val      => Current_Phase := Feedback_Anal;
         when Feedback_Anal =>
            case Signal is
               when None          => Current_Phase := Provenance_Seal;
               when Retry_Static  =>
                  Put_Line ("[AVRS] ⤴ Retrying static lift...");
                  Current_Phase := Static_Lift;
               when Retry_Dynamic =>
                  Put_Line ("[AVRS] ⤴ Retrying dynamic probing...");
                  Current_Phase := Dyn_Conform;
               when Retry_Primitive =>
                  Put_Line ("[AVRS] ⤴ Retrying primitive extraction...");
                  Await_Operator ("Offset/primitive was wrong. Adjust hypothesis.txt.");
                  Current_Phase := Primitive_Extract;
               when Retry_Payload =>
                  Put_Line ("[AVRS] ⤴ Retrying payload synthesis...");
                  Await_Operator ("Payload failed. Write exploit_override.pl.");
                  Current_Phase := Payload_Synth;
               when Escalate =>
                  Put_Line ("[AVRS] ⚠ Escalating to human review.");
                  Current_Phase := Provenance_Seal;
            end case;
         when Provenance_Seal =>
            Put_Line ("[AVRS] ✓ Pipeline complete.");
            Current_Phase := Provenance_Seal;
      end case;

      Iteration := Iteration + 1;
      if Iteration > Max_Iterations then
         Put_Line ("[AVRS] ⚠ Max iterations reached. Terminating.");
         Current_Phase := Provenance_Seal;
      end if;
   end Transition;

   procedure Main_Loop is
      Result : Phase_Result;
   begin
      Put_Line ("");
      Put_Line ("╔══════════════════════════════════════════════╗");
      Put_Line ("║   AVRS v3.0 Cybernetic – Copyleft Body      ║");
      Put_Line ("║   the operator Strategic Executive Online         ║");
      Put_Line ("╚══════════════════════════════════════════════╝");
      Put_Line ("");

      loop
         Put_Line ("─── Phase: " & Phase'Image (Current_Phase) &
                   " (iteration" & Integer'Image (Iteration) & ") ───");

         Run_Phase (Current_Phase, Result);

         if Result.Success then
            Put_Line ("  [✓] Phase complete. Exit:" & Integer'Image (Result.Exit_Code));
         else
            Put_Line ("  [!] Phase failed. Exit:" & Integer'Image (Result.Exit_Code));
            declare
               F : File_Type;
            begin
               Create (F, Out_File, Workspace & "/data/memory/last_error.txt");
               Put_Line (F, Phase'Image (Current_Phase) & " exit=" &
                         Integer'Image (Result.Exit_Code));
               Close (F);
            end;
         end if;

         declare
            F : File_Type;
         begin
            Create (F, Out_File, Workspace & "/data/memory/current_phase.txt");
            Put_Line (F, Phase'Image (Current_Phase));
            Close (F);
         end;

         declare
            Phase_Before : constant Phase := Current_Phase;
         begin
            Transition (Current_Phase, Result);
            exit when Current_Phase = Provenance_Seal and then Phase_Before = Provenance_Seal;
         end;
      end loop;

      Put_Line ("");
      Put_Line ("══════════════════════════════════════════════");
      Put_Line ("  AVRS v3.0 – Complete.");
      Put_Line ("  Final Report: " & Workspace & "/results/final_report.txt");
      Put_Line ("══════════════════════════════════════════════");
   end Main_Loop;

begin
   Main_Loop;
end Avrs_Core;

-- AVRS v3.0 Cybernetic – Core Loop Specification
pragma SPARK_Mode (Off);  -- Off for I/O; cyber_loop.ads has SPARK contracts

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Integer_Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNAT.OS_Lib;

package Avrs_Core is -- are you serious right now?

   type Phase is (Bootstrap, Env_Scan, Static_Lift, Cap_Model,
                   Taint_Flow, Dyn_Conform, Side_Channel, Anomaly_Fusion,
                   Primitive_Extract, Payload_Synth, Sandbox_Val,
                   Feedback_Anal, Provenance_Seal);

   type Feedback_Signal is (None, Retry_Static, Retry_Dynamic,
                             Retry_Primitive, Retry_Payload, Escalate);

   type Phase_Result is record
      Success   : Boolean;
      Exit_Code : Integer;
      Stdout    : Unbounded_String;
      Stderr    : Unbounded_String;
      Duration  : Float;
   end record;

   -- State machine
   Current_Phase : Phase := Bootstrap;
   Iteration     : Natural := 0;
   Max_Iterations : constant Natural := 10;

   -- Feedback queue
   Signal : Feedback_Signal := None;

   -- the operator integration
   Cortex_Hypothesis_File : constant String := "../kerebral/hypothesis.txt";
   Cortex_Exploit_File    : constant String := "../kerebral/exploit_override.pl";
   Cortex_Retrain_File    : constant String := "../kerebral/retrain_decision.txt";
   Cortex_Report_File     : constant String := "../kerebral/after_action_report.txt";

   -- Phase execution
   procedure Run_Phase (P : in Phase; Result : out Phase_Result);
   function Check_Cortex_Override (Path : String) return Boolean;
   function Read_Cortex_File (Path : String) return Unbounded_String;
   procedure Transition (P : Phase; Result : Phase_Result);
   procedure Main_Loop;

end Avrs_Core;

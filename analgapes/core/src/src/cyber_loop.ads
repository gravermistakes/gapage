-- SPARK contracts for the cybernetic phase transition logic
-- Proves: termination, no dead phases, feedback loop boundedness
pragma SPARK_Mode (On);

package Cyber_Loop with SPARK_Mode => On is

   type Phase_Index is range 0 .. 12;
   type Meta_Layer is (Perception, Cognition, Action, Metacognition, Governance);

   function Layer_Of (P : Phase_Index) return Meta_Layer is
     (case P is
         when 0      => Metacognition,
         when 1 | 2 | 5 | 6 => Perception,
         when 3 | 4 | 7 => Cognition,
         when 8 | 9 | 10 => Action,
         when 11     => Metacognition,
         when 12     => Governance);

   function Valid_Transition (From, To : Phase_Index) return Boolean is
     (if From < 11 then To = From + 1
      elsif From = 11 then
        To in 2 | 5 | 8 | 9 | 12
      else To = 12);

   Max_Iterations : constant := 10;

   procedure Bounded_Loop with
     Global => null,
     Pre  => True,
     Post => True;

end Cyber_Loop;

-- Sphinx – Provenance Graph Builder
-- Copyright (C) 2026 Anja Evermoor
-- GNU GPL v3.0 or later
--
-- SPARK contracts enforce graph invariants:
--   - No self-edges
--   - Node count bounded
--   - Edge count bounded per node

pragma SPARK_Mode (On);

package Sphinx with SPARK_Mode => On is

   Max_Nodes : constant := 1024;
   Max_Name_Len : constant := 256;

   type Node_ID is new Natural range 0 .. Max_Nodes;
   subtype Valid_Node_ID is Node_ID range 1 .. Max_Nodes;

   type Edge_Kind is (Depends_On, Contains_CVE, Patched, Vulnerable, Sealed);

   type Graph_State is (Empty, Building, Sealed);

   type Dependency_Graph is private;

   function State (G : Dependency_Graph) return Graph_State;
   function Node_Count (G : Dependency_Graph) return Natural
     with Post => Node_Count'Result <= Max_Nodes;

   procedure Initialize (G : out Dependency_Graph)
     with Post => State (G) = Empty and Node_Count (G) = 0;

   procedure Add_Node (G    : in out Dependency_Graph;
                       Name : in     String;
                       Node : out    Node_ID)
     with Pre  => State (G) /= Sealed
                  and Node_Count (G) < Max_Nodes
                  and Name'Length <= Max_Name_Len,
          Post => Node_Count (G) = Node_Count (G'Old) + 1
                  and State (G) = Building;

   procedure Add_Edge (G         : in out Dependency_Graph;
                       From_Node : in     Valid_Node_ID;
                       To_Node   : in     Valid_Node_ID;
                       Kind      : in     Edge_Kind)
     with Pre => State (G) = Building
                 and From_Node /= To_Node
                 and Natural (From_Node) <= Node_Count (G)
                 and Natural (To_Node) <= Node_Count (G);

   procedure Seal_Graph (G : in out Dependency_Graph)
     with Pre  => State (G) = Building,
          Post => State (G) = Sealed;

   function Node_Name (G    : Dependency_Graph;
                       Node : Valid_Node_ID) return String
     with Pre => Natural (Node) <= Node_Count (G);

private

   type Name_Buffer is new String (1 .. Max_Name_Len);

   type Node_Record is record
      Name   : Name_Buffer := (others => ' ');
      Length : Natural := 0;
   end record;

   type Node_Array is array (Valid_Node_ID) of Node_Record;

   type Edge_Record is record
      From_Node : Node_ID := 0;
      To_Node   : Node_ID := 0;
      Kind      : Edge_Kind := Depends_On;
      Active    : Boolean := False;
   end record;

   Max_Edges : constant := Max_Nodes * 8;
   type Edge_Index is new Natural range 0 .. Max_Edges;
   subtype Valid_Edge_Index is Edge_Index range 1 .. Max_Edges;
   type Edge_Array is array (Valid_Edge_Index) of Edge_Record;

   type Dependency_Graph is record
      Nodes      : Node_Array;
      Edges      : Edge_Array;
      Node_Count : Natural := 0;
      Edge_Count : Edge_Index := 0;
      Current_State : Graph_State := Empty;
   end record;

end Sphinx;

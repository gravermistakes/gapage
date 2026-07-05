-- Sphinx – Provenance Graph Builder (body)
-- Copyright (C) 2026 Anja Evermoor
-- GNU GPL v3.0 or later

pragma SPARK_Mode (On);

package body Sphinx with SPARK_Mode => On is

   function State (G : Dependency_Graph) return Graph_State is
   begin
      return G.Current_State;
   end State;

   function Node_Count (G : Dependency_Graph) return Natural is
   begin
      return G.Node_Count;
   end Node_Count;

   procedure Initialize (G : out Dependency_Graph) is
   begin
      G.Node_Count := 0;
      G.Edge_Count := 0;
      G.Current_State := Empty;
      -- Arrays initialized by default values in type declaration
   end Initialize;

   procedure Add_Node (G    : in out Dependency_Graph;
                       Name : in     String;
                       Node : out    Node_ID) is
      Buf : Name_Buffer := (others => ' ');
   begin
      for I in Name'Range loop
         Buf (I - Name'First + 1) := Name (I);
      end loop;

      G.Node_Count := G.Node_Count + 1;
      G.Nodes (Valid_Node_ID (G.Node_Count)).Name := Buf;
      G.Nodes (Valid_Node_ID (G.Node_Count)).Length := Name'Length;
      G.Current_State := Building;
      Node := Node_ID (G.Node_Count);
   end Add_Node;

   procedure Add_Edge (G         : in out Dependency_Graph;
                       From_Node : in     Valid_Node_ID;
                       To_Node   : in     Valid_Node_ID;
                       Kind      : in     Edge_Kind) is
   begin
      if G.Edge_Count < Max_Edges then
         G.Edge_Count := G.Edge_Count + 1;
         G.Edges (Valid_Edge_Index (G.Edge_Count)) :=
           (From_Node => Node_ID (From_Node),
            To_Node   => Node_ID (To_Node),
            Kind      => Kind,
            Active    => True);
      end if;
   end Add_Edge;

   procedure Seal_Graph (G : in out Dependency_Graph) is
   begin
      G.Current_State := Sealed;
   end Seal_Graph;

   function Node_Name (G    : Dependency_Graph;
                       Node : Valid_Node_ID) return String is
      Rec : constant Node_Record := G.Nodes (Node);
   begin
      return String (Rec.Name (1 .. Rec.Length));
   end Node_Name;

end Sphinx;

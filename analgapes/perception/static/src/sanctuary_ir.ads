-- Sanctuary IR v3.0 – Shared types for SLEDGE and Capability Graph
-- Supports x86-64 and AArch64 (bare-metal/EL3) analysis
-- SPDX-License-Identifier: GPL-3.0-or-later
pragma SPARK_Mode (On);

package Sanctuary_IR with SPARK_Mode => On is

   type Arch_Type is (X86_64, AArch64, Unknown_Arch);
   type Exception_Level is (EL0_App, EL1_Kernel, EL2_Hypervisor, EL3_Monitor);

   type Permission is (Read, Write, Execute, Cap_Invoke, Mmio, Secure);
   type Permission_Set is array (Permission) of Boolean;

   type Capability is record
      Base_Addr  : Natural;
      Bounds     : Positive;
      Perms      : Permission_Set;
      Object_ID  : Natural;
      Priv_Level : Exception_Level;
   end record;

   type IR_Node_Kind is (
      Load, Store, Branch, Call, Ret, Arith, Unknown,
      Smc, Hvc, Svc,               -- Exception generation
      Sys_Reg,                      -- MSR/MRS system register access
      Mmio_Write, Mmio_Read,        -- Memory-mapped I/O
      Mov_Imm,                      -- Immediate loading (address construction)
      Barrier                       -- DMB/DSB/ISB
   );

   Max_Reg_Name : constant := 8;
   subtype Reg_Name is String (1 .. Max_Reg_Name);

   Max_Sysreg : constant := 24;
   subtype Sysreg_Name is String (1 .. Max_Sysreg);

   type IR_Node (Kind : IR_Node_Kind := Unknown) is record
      case Kind is
         when Load | Store =>
            Reg : Reg_Name;  Cap : Capability;
         when Branch | Call =>
            Target : Capability;
         when Ret => null;
         when Arith =>
            Opcode : String (1 .. 12);
         when Smc | Hvc | Svc =>
            Imm16 : Natural;
         when Sys_Reg =>
            Sys_Op   : Reg_Name;
            Sys_Name : Sysreg_Name;
            Gp_Reg   : Reg_Name;
         when Mmio_Write | Mmio_Read =>
            Mmio_Addr : Natural;
            Mmio_Val  : Natural;
            Mmio_Cap  : Capability;
         when Mov_Imm =>
            Dest_Reg : Reg_Name;
            Imm_Val  : Natural;
            Shift    : Natural;
         when Barrier =>
            Bar_Kind : Reg_Name;
         when Unknown =>
            Raw_Byte : Natural;
      end case;
   end record;

   Max_Nodes : constant := 262144;

   -- QFPROM known base addresses (Qualcomm SoC family)
   QFPROM_Base_SM8650 : constant := 16#00780000#;
   QFPROM_Range_Size  : constant := 16#00010000#;

   function Is_QFPROM_Addr (Addr : Natural) return Boolean is
     (Addr >= QFPROM_Base_SM8650 and then
      Addr < QFPROM_Base_SM8650 + QFPROM_Range_Size);

end Sanctuary_IR;

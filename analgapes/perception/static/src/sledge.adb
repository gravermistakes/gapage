-- SLEDGE v3.0: Copyleft Multi-Mode Binary Analyser (Ada/SPARK)
-- Modes: strings, elf_map, entropy, lift, full
-- Architectures: x86-64, AArch64 (bare-metal/EL3)
-- SPDX-License-Identifier: GPL-3.0-or-later
with Ada.Text_IO;            use Ada.Text_IO;
with Ada.Command_Line;       use Ada.Command_Line;
with Ada.Streams.Stream_IO;
with Ada.Characters.Handling; use Ada.Characters.Handling;
with Interfaces;              use Interfaces;
with Sanctuary_IR;            use Sanctuary_IR;

procedure Sledge is

   Max_File : constant := 16_777_216;
   type Byte_Array is array (Positive range <>) of Unsigned_8;

   ELF_MAG : constant Byte_Array (1 .. 4) := (16#7F#, 16#45#, 16#4C#, 16#46#);
   EM_X86_64  : constant Unsigned_16 := 16#3E#;
   EM_AARCH64 : constant Unsigned_16 := 16#B7#;

   -- Shared binary data
   Data     : Byte_Array (1 .. Max_File);
   Last_Idx : Natural := 0;

   function U16 (Off : Positive) return Unsigned_16 is
   begin
      return Unsigned_16 (Data (Off)) or
             Shift_Left (Unsigned_16 (Data (Off + 1)), 8);
   end U16;

   function U32 (Off : Positive) return Unsigned_32 is
   begin
      return Unsigned_32 (U16 (Off)) or
             Shift_Left (Unsigned_32 (U16 (Off + 2)), 16);
   end U32;

   function U64 (Off : Positive) return Unsigned_64 is
   begin
      return Unsigned_64 (U32 (Off)) or
             Shift_Left (Unsigned_64 (U32 (Off + 4)), 32);
   end U64;

   function Is_Elf return Boolean is
   begin
      return Last_Idx >= 64 and then
             Data (1) = ELF_MAG (1) and then Data (2) = ELF_MAG (2) and then
             Data (3) = ELF_MAG (3) and then Data (4) = ELF_MAG (4);
   end Is_Elf;

   function Detect_Arch return Arch_Type is
   begin
      if not Is_Elf then return Unknown_Arch; end if;
      declare M : constant Unsigned_16 := U16 (19); begin
         if    M = EM_AARCH64 then return AArch64;
         elsif M = EM_X86_64  then return X86_64;
         else  return Unknown_Arch;
         end if;
      end;
   end Detect_Arch;

   function Pad8 (S : String) return Reg_Name is
      R : Reg_Name := (others => ' ');
   begin
      for I in S'Range loop
         exit when I - S'First + 1 > Max_Reg_Name;
         R (I - S'First + 1) := S (I);
      end loop;
      return R;
   end Pad8;

   function EL3_Cap (Addr : Natural; P : Permission_Set) return Capability is
   begin
      return (Base_Addr => Addr, Bounds => 4, Perms => P,
              Object_ID => Natural (U64 (Addr) xor 16#5EC0DE#), Priv_Level => EL3_Monitor);
   end EL3_Cap;

   function Def_Cap (Addr : Natural; P : Permission_Set) return Capability is
   begin
      return (Base_Addr => Addr, Bounds => 4, Perms => P,
              Object_ID => Natural (U64 (Addr) xor 16#5EC0DE#), Priv_Level => EL0_App);
   end Def_Cap;

   -- Read a C string from offset
   function CStr (Off : Natural; Max_Len : Natural := 128) return String is
      S : String (1 .. Max_Len);
      L : Natural := 0;
   begin
      for I in 0 .. Max_Len - 1 loop
         exit when Off + I + 1 > Last_Idx;
         exit when Data (Off + I + 1) = 0;
         L := L + 1;
         S (L) := Character'Val (Data (Off + I + 1));
      end loop;
      return S (1 .. L);
   end CStr;

   ----------------------------------------------------------------
   -- MODE: STRINGS — extract printable strings with pattern tagging
   ----------------------------------------------------------------
   procedure Mode_Strings (F : File_Type) is
      Min_Len : constant := 4;
      I       : Natural := 1;
      Total   : Natural := 0;
      Proto   : Natural := 0;

      function Is_Printable (C : Unsigned_8) return Boolean is
      begin
         return (C >= 16#20# and C < 16#7F#) or C = 16#0A# or C = 16#09#;
      end Is_Printable;

      function Is_Protocol (S : String) return Boolean is
      begin
         -- Firehose XML protocol commands
         for J in S'First .. S'Last - 4 loop
            if S (J .. J + 4) = "<patc" or else S (J .. J + 4) = "<peek" or else
               S (J .. J + 4) = "<poke" or else S (J .. J + 4) = "<conf" or else
               S (J .. J + 4) = "<read" or else S (J .. J + 4) = "<prog" or else
               S (J .. J + 4) = "<eras" then return True; end if;
         end loop;
         -- QFPROM/Knox/security strings
         for J in S'First .. S'Last - 3 loop
            if S (J .. J + 3) = "qfpr" or else S (J .. J + 3) = "QFPR" or else
               S (J .. J + 3) = "fuse" or else S (J .. J + 3) = "FUSE" or else
               S (J .. J + 3) = "KNOX" or else S (J .. J + 3) = "knox" or else
               S (J .. J + 3) = "warr" or else S (J .. J + 3) = "WARR" or else
               S (J .. J + 3) = "TIMA" or else S (J .. J + 3) = "BLDP" or else
               S (J .. J + 3) = "iccc" or else S (J .. J + 3) = "ICCC" or else
               S (J .. J + 3) = "VBAR" or else S (J .. J + 3) = "SCR_" then
               return True;
            end if;
         end loop;
         return False;
      end Is_Protocol;

   begin
      Put_Line (F, "SLEDGE_STRINGS(size=" & Natural'Image (Last_Idx) & ")");
      while I <= Last_Idx loop
         declare
            Start : constant Natural := I;
            S     : String (1 .. 1024);
            L     : Natural := 0;
         begin
            while I <= Last_Idx and then Is_Printable (Data (I)) and then L < 1024 loop
               L := L + 1;
               S (L) := Character'Val (Data (I));
               I := I + 1;
            end loop;
            if L >= Min_Len then
               Total := Total + 1;
               Put (F, "STR(off=0x");
               declare
                  Hex : String (1 .. 8);
                  V   : Natural := Start - 1;
                  Dig : constant String := "0123456789ABCDEF";
               begin
                  for H in reverse Hex'Range loop
                     Hex (H) := Dig (1 + (V mod 16));
                     V := V / 16;
                  end loop;
                  Put (F, Hex);
               end;
               Put (F, ",len=" & Natural'Image (L));
               if L >= 5 and then Is_Protocol (S (1 .. L)) then
                  Put (F, ",tag=PROTOCOL");
                  Proto := Proto + 1;
               end if;
               Put (F, ",val=""");
               -- Truncate long strings for output
               if L > 80 then
                  Put (F, S (1 .. 80) & "...");
               else
                  Put (F, S (1 .. L));
               end if;
               Put_Line (F, """)");
            end if;
         end;
         if I <= Last_Idx then I := I + 1; end if;
      end loop;
      Put_Line (F, "STRINGS_SUMMARY(total=" & Natural'Image (Total) &
        ",protocol=" & Natural'Image (Proto) & ")");
   end Mode_Strings;

   ----------------------------------------------------------------
   -- MODE: ELF_MAP — parse ELF structure
   ----------------------------------------------------------------
   procedure Mode_Elf_Map (F : File_Type) is
   begin
      if not Is_Elf then
         Put_Line (F, "ELF_MAP(status=NOT_ELF,format=RAW_BINARY)");
         return;
      end if;
      declare
         E_Type   : constant Unsigned_16 := U16 (17);
         E_Mach   : constant Unsigned_16 := U16 (19);
         E_Entry  : constant Unsigned_64 := U64 (25);
         E_Phoff  : constant Unsigned_64 := U64 (33);
         E_Shoff  : constant Unsigned_64 := U64 (41);
         E_Phnum  : constant Unsigned_16 := U16 (57);
         E_Shent  : constant Unsigned_16 := U16 (59);
         E_Shnum  : constant Unsigned_16 := U16 (61);
         E_Shstr  : constant Unsigned_16 := U16 (63);
         Shstrtab : Natural := 0;
      begin
         Put_Line (F, "ELF_MAP(machine=0x" & Unsigned_16'Image (E_Mach) &
           ",entry=0x" & Unsigned_64'Image (E_Entry) &
           ",phnum=" & Unsigned_16'Image (E_Phnum) &
           ",shnum=" & Unsigned_16'Image (E_Shnum) & ")");

         -- Program headers (segments)
         for I in 0 .. Natural (E_Phnum) - 1 loop
            declare
               Off : constant Natural := Natural (E_Phoff) + I * 56 + 1;
               P_Type  : constant Unsigned_32 := U32 (Off);
               P_Flags : constant Unsigned_32 := U32 (Off + 4);
               P_Off   : constant Unsigned_64 := U64 (Off + 8);
               P_Vaddr : constant Unsigned_64 := U64 (Off + 16);
               P_Filesz : constant Unsigned_64 := U64 (Off + 32);
               P_Memsz  : constant Unsigned_64 := U64 (Off + 40);
               Perm : String (1 .. 3) := "---";
            begin
               if (P_Flags and 4) /= 0 then Perm (1) := 'R'; end if;
               if (P_Flags and 2) /= 0 then Perm (2) := 'W'; end if;
               if (P_Flags and 1) /= 0 then Perm (3) := 'X'; end if;
               Put_Line (F, "SEGMENT(idx=" & Natural'Image (I) &
                 ",type=" & Unsigned_32'Image (P_Type) &
                 ",perm=" & Perm &
                 ",vaddr=0x" & Unsigned_64'Image (P_Vaddr) &
                 ",filesz=" & Unsigned_64'Image (P_Filesz) &
                 ",memsz=" & Unsigned_64'Image (P_Memsz) &
                 ",off=" & Unsigned_64'Image (P_Off) & ")");
            end;
         end loop;

         -- Locate shstrtab
         if Natural (E_Shstr) < Natural (E_Shnum) then
            Shstrtab := Natural (U64 (Natural (E_Shoff) + Natural (E_Shstr) * 64 + 24 + 1));
         end if;

         -- Section headers
         for I in 0 .. Natural (E_Shnum) - 1 loop
            declare
               Off : constant Natural := Natural (E_Shoff) + I * 64 + 1;
               Sh_Name  : constant Unsigned_32 := U32 (Off);
               Sh_Type  : constant Unsigned_32 := U32 (Off + 4);
               Sh_Flags : constant Unsigned_64 := U64 (Off + 8);
               Sh_Addr  : constant Unsigned_64 := U64 (Off + 16);
               Sh_Off   : constant Unsigned_64 := U64 (Off + 24);
               Sh_Size  : constant Unsigned_64 := U64 (Off + 32);
               Name     : constant String :=
                 (if Shstrtab > 0 then CStr (Shstrtab + Natural (Sh_Name))
                  else "sec_" & Natural'Image (I));
               Flags_S  : String (1 .. 3) := "---";
            begin
               if (Sh_Flags and 1) /= 0 then Flags_S (1) := 'W'; end if;
               if (Sh_Flags and 2) /= 0 then Flags_S (2) := 'A'; end if;
               if (Sh_Flags and 4) /= 0 then Flags_S (3) := 'X'; end if;
               Put_Line (F, "SECTION(idx=" & Natural'Image (I) &
                 ",name=" & Name &
                 ",type=" & Unsigned_32'Image (Sh_Type) &
                 ",flags=" & Flags_S &
                 ",addr=0x" & Unsigned_64'Image (Sh_Addr) &
                 ",off=" & Unsigned_64'Image (Sh_Off) &
                 ",size=" & Unsigned_64'Image (Sh_Size) & ")");
            end;
         end loop;
      end;
   end Mode_Elf_Map;

   ----------------------------------------------------------------
   -- MODE: ENTROPY — sliding-window Shannon entropy
   ----------------------------------------------------------------
   procedure Mode_Entropy (F : File_Type) is
      Window : constant := 256;
      Step   : constant := 64;
      High_Regions : Natural := 0;
      Sum_Entropy  : Float := 0.0;
      Samples      : Natural := 0;

      function Log2 (X : Float) return Float is
      begin
         -- ln(x)/ln(2)
         if X <= 0.0 then return 0.0; end if;
         -- Use natural log approximation via Ada.Numerics if available,
         -- otherwise simple series for our range [0,1]
         declare
            Ln2 : constant Float := 0.693147;
            -- For p in (0,1]: ln(p) via p-1 series (adequate for entropy)
            P   : constant Float := X;
            Lnp : Float;
         begin
            if P >= 1.0 then return 0.0; end if;
            -- ln(p) ≈ -(1-p) - (1-p)²/2 - (1-p)³/3  (first 6 terms)
            declare
               Q : constant Float := 1.0 - P;
            begin
               Lnp := -(Q + Q**2/2.0 + Q**3/3.0 + Q**4/4.0 + Q**5/5.0 + Q**6/6.0);
            end;
            return Lnp / Ln2;
         end;
      end Log2;

   begin
      Put_Line (F, "SLEDGE_ENTROPY(size=" & Natural'Image (Last_Idx) &
        ",window=" & Natural'Image (Window) & ")");

      declare
         I : Natural := 1;
      begin
         while I + Window - 1 <= Last_Idx loop
            declare
               Freq : array (0 .. 255) of Natural := (others => 0);
               H    : Float := 0.0;
            begin
               for J in 0 .. Window - 1 loop
                  Freq (Natural (Data (I + J))) := Freq (Natural (Data (I + J))) + 1;
               end loop;
               for B in 0 .. 255 loop
                  if Freq (B) > 0 then
                     declare
                        P : constant Float := Float (Freq (B)) / Float (Window);
                     begin
                        H := H - P * Log2 (P);
                     end;
                  end if;
               end loop;
               Sum_Entropy := Sum_Entropy + H;
               Samples := Samples + 1;
               if H >= 7.0 then
                  Put_Line (F, "HIGH_ENTROPY(off=0x" & Natural'Image (I - 1) &
                    ",bits=" & Float'Image (H) & ")");
                  High_Regions := High_Regions + 1;
               end if;
            end;
            I := I + Step;
         end loop;
      end;

      Put_Line (F, "ENTROPY_SUMMARY(avg=" &
        Float'Image (if Samples > 0 then Sum_Entropy / Float (Samples) else 0.0) &
        ",high_regions=" & Natural'Image (High_Regions) & ")");
   end Mode_Entropy;

   ----------------------------------------------------------------
   -- LIFT: AArch64 instruction decoder
   ----------------------------------------------------------------
   procedure Lift_A64 (Insn : Unsigned_32; Addr : Natural;
                       Node : out IR_Node; Cap : out Capability) is
      Rd : constant Natural := Natural (Insn and 16#1F#);
      Rn : constant Natural := Natural (Shift_Right (Insn, 5) and 16#1F#);
   begin
      Cap := EL3_Cap (Addr, (Execute => True, others => False));

      -- SMC #imm16
      if (Insn and 16#FFE0001F#) = 16#D4000003# then
         Node := (Kind => Smc,
                  Imm16 => Natural (Shift_Right (Insn, 5) and 16#FFFF#));
         Cap := EL3_Cap (Addr, (Execute | Secure => True, others => False));
         return;
      end if;
      -- HVC
      if (Insn and 16#FFE0001F#) = 16#D4000002# then
         Node := (Kind => Hvc,
                  Imm16 => Natural (Shift_Right (Insn, 5) and 16#FFFF#));
         return;
      end if;
      -- SVC
      if (Insn and 16#FFE0001F#) = 16#D4000001# then
         Node := (Kind => Svc,
                  Imm16 => Natural (Shift_Right (Insn, 5) and 16#FFFF#));
         return;
      end if;
      -- RET
      if Insn = 16#D65F03C0# then Node := (Kind => Ret); return; end if;
      -- NOP
      if Insn = 16#D503201F# then
         Node := (Kind => Arith, Opcode => "NOP         "); return;
      end if;
      -- MSR
      if (Insn and 16#FFF00000#) = 16#D5100000# then
         Node := (Kind => Sys_Reg, Sys_Op => Pad8 ("MSR"),
                  Sys_Name => (others => ' '), Gp_Reg => Pad8 ("X" & Natural'Image (Rd)));
         Cap := EL3_Cap (Addr, (Write | Secure => True, others => False));
         return;
      end if;
      -- MRS
      if (Insn and 16#FFF00000#) = 16#D5300000# then
         Node := (Kind => Sys_Reg, Sys_Op => Pad8 ("MRS"),
                  Sys_Name => (others => ' '), Gp_Reg => Pad8 ("X" & Natural'Image (Rd)));
         Cap := EL3_Cap (Addr, (Read | Secure => True, others => False));
         return;
      end if;
      -- STR 32-bit
      if (Insn and 16#FFC00000#) = 16#B9000000# then
         Node := (Kind => Store, Reg => Pad8 ("X" & Natural'Image (Rd)),
                  Cap => EL3_Cap (Addr, (Write | Mmio => True, others => False)));
         return;
      end if;
      -- STR 64-bit
      if (Insn and 16#FFC00000#) = 16#F9000000# then
         Node := (Kind => Store, Reg => Pad8 ("X" & Natural'Image (Rd)),
                  Cap => EL3_Cap (Addr, (Write | Mmio => True, others => False)));
         return;
      end if;
      -- LDR 32-bit
      if (Insn and 16#FFC00000#) = 16#B9400000# then
         Node := (Kind => Load, Reg => Pad8 ("X" & Natural'Image (Rd)),
                  Cap => EL3_Cap (Addr, (Read => True, others => False)));
         return;
      end if;
      -- LDR 64-bit
      if (Insn and 16#FFC00000#) = 16#F9400000# then
         Node := (Kind => Load, Reg => Pad8 ("X" & Natural'Image (Rd)),
                  Cap => EL3_Cap (Addr, (Read => True, others => False)));
         return;
      end if;
      -- BL (direct call)
      if (Insn and 16#FC000000#) = 16#94000000# then
         declare Off26 : constant Natural := Natural (Insn and 16#03FFFFFF#); begin
            Node := (Kind => Call,
                     Target => EL3_Cap (Addr + Off26 * 4, (Execute => True, others => False)));
         end; return;
      end if;
      -- B (unconditional)
      if (Insn and 16#FC000000#) = 16#14000000# then
         declare Off26 : constant Natural := Natural (Insn and 16#03FFFFFF#); begin
            Node := (Kind => Branch,
                     Target => EL3_Cap (Addr + Off26 * 4, (Execute => True, others => False)));
         end; return;
      end if;
      -- BLR Xn
      if (Insn and 16#FFFFFC1F#) = 16#D63F0000# then
         Node := (Kind => Call,
                  Target => EL3_Cap (Rn, (Execute => True, others => False)));
         return;
      end if;
      -- BR Xn
      if (Insn and 16#FFFFFC1F#) = 16#D61F0000# then
         Node := (Kind => Branch,
                  Target => EL3_Cap (Rn, (Execute => True, others => False)));
         return;
      end if;
      -- MOVZ
      if (Insn and 16#FF800000#) = 16#D2800000# then
         Node := (Kind => Mov_Imm, Dest_Reg => Pad8 ("X" & Natural'Image (Rd)),
                  Imm_Val => Natural (Shift_Right (Insn, 5) and 16#FFFF#),
                  Shift   => Natural (Shift_Right (Insn, 21) and 3) * 16);
         return;
      end if;
      -- MOVK
      if (Insn and 16#FF800000#) = 16#F2800000# then
         Node := (Kind => Mov_Imm, Dest_Reg => Pad8 ("X" & Natural'Image (Rd)),
                  Imm_Val => Natural (Shift_Right (Insn, 5) and 16#FFFF#),
                  Shift   => Natural (Shift_Right (Insn, 21) and 3) * 16);
         return;
      end if;
      -- DSB/DMB/ISB
      if (Insn and 16#FFFFF01F#) = 16#D503301F# then
         declare Op2 : constant Natural := Natural (Shift_Right (Insn, 5) and 7); begin
            Node := (Kind => Barrier, Bar_Kind =>
              (if Op2 = 4 then Pad8 ("DSB") elsif Op2 = 5 then Pad8 ("DMB")
               elsif Op2 = 6 then Pad8 ("ISB") else Pad8 ("UNK")));
         end; return;
      end if;
      -- B.cond (conditional branch)
      if (Insn and 16#FF000010#) = 16#54000000# then
         declare Off19 : constant Natural := Natural (Shift_Right (Insn, 5) and 16#7FFFF#); begin
            Node := (Kind => Branch,
                     Target => EL3_Cap (Addr + Off19 * 4, (Execute => True, others => False)));
         end; return;
      end if;
      -- CBZ/CBNZ
      if (Insn and 16#7E000000#) = 16#34000000# then
         declare Off19 : constant Natural := Natural (Shift_Right (Insn, 5) and 16#7FFFF#); begin
            Node := (Kind => Branch,
                     Target => EL3_Cap (Addr + Off19 * 4, (Execute => True, others => False)));
         end; return;
      end if;
      -- ADD immediate
      if (Insn and 16#7F000000#) = 16#11000000# then
         Node := (Kind => Arith, Opcode => "ADD_IMM     "); return;
      end if;
      -- SUB immediate
      if (Insn and 16#7F000000#) = 16#51000000# then
         Node := (Kind => Arith, Opcode => "SUB_IMM     "); return;
      end if;
      -- STP (store pair — common in prologues)
      if (Insn and 16#7FC00000#) = 16#29000000# or else
         (Insn and 16#7FC00000#) = 16#A9000000# then
         Node := (Kind => Store, Reg => Pad8 ("PAIR"),
                  Cap => EL3_Cap (Addr, (Write => True, others => False)));
         return;
      end if;
      -- LDP (load pair — common in epilogues)
      if (Insn and 16#7FC00000#) = 16#29400000# or else
         (Insn and 16#7FC00000#) = 16#A9400000# then
         Node := (Kind => Load, Reg => Pad8 ("PAIR"),
                  Cap => EL3_Cap (Addr, (Read => True, others => False)));
         return;
      end if;

      -- Unknown
      Node := (Kind => Unknown, Raw_Byte => Natural (Insn and 16#FF#));
   end Lift_A64;

   ----------------------------------------------------------------
   -- LIFT: x86-64 decoder (basic)
   ----------------------------------------------------------------
   procedure Lift_X64 (Op : Byte_Array; Addr : Natural;
                       Node : out IR_Node; Cap : out Capability) is
   begin
      Cap := Def_Cap (Addr, (Execute => True, others => False));
      if Op'Length = 0 then Node := (Kind => Unknown, Raw_Byte => 0); return; end if;
      case Op (Op'First) is
         when 16#48# =>
            if Op'Length >= 2 then
               case Op (Op'First + 1) is
                  when 16#8B# => Node := (Kind => Load, Reg => Pad8 ("RAX"),
                     Cap => Def_Cap (Addr, (Read => True, others => False)));
                  when 16#89# => Node := (Kind => Store, Reg => Pad8 ("MEM"),
                     Cap => Def_Cap (Addr, (Write => True, others => False)));
                  when others => Node := (Kind => Arith, Opcode => "REX_UNK     ");
               end case;
            else Node := (Kind => Unknown, Raw_Byte => Natural (Op (Op'First))); end if;
         when 16#E9# => Node := (Kind => Branch,
            Target => Def_Cap (Addr + 5, (Execute => True, others => False)));
         when 16#E8# => Node := (Kind => Call,
            Target => Def_Cap (Addr + 5, (Execute => True, others => False)));
         when 16#C3# => Node := (Kind => Ret);
         when 16#89# => Node := (Kind => Store, Reg => Pad8 ("MEM"),
            Cap => Def_Cap (Addr, (Write => True, others => False)));
         when 16#8B# => Node := (Kind => Load, Reg => Pad8 ("REG"),
            Cap => Def_Cap (Addr, (Read => True, others => False)));
         when others => Node := (Kind => Unknown,
            Raw_Byte => Natural (Op (Op'First)));
      end case;
   end Lift_X64;

   ----------------------------------------------------------------
   -- MODE: LIFT — disassemble and emit IR
   ----------------------------------------------------------------
   procedure Mode_Lift (F : File_Type; Arch : Arch_Type) is
      I    : Natural;
      Node : IR_Node;
      Cap  : Capability;
      A_Str : constant String :=
        (if Arch = AArch64 then "AARCH64" else "X86_64");
   begin
      Put_Line (F, "SLEDGE_LIFT(arch=" & A_Str &
        ",size=" & Natural'Image (Last_Idx) & ")");

      -- Determine start offset from ELF entry
      I := 1;
      if Is_Elf then
         declare E : constant Unsigned_64 := U64 (25); begin
            if E < Unsigned_64 (Last_Idx) then I := Natural (E) + 1; end if;
         end;
      end if;

      if Arch = AArch64 then
         while I + 3 <= Last_Idx loop
            Lift_A64 (U32 (I), I - 1, Node, Cap);
            -- Output non-unknown nodes
            case Node.Kind is
               when Unknown => null;
               when Load | Store =>
                  Put_Line (F, "PROOF(OP:" &
                    (if Node.Kind = Load then "LOAD" else "STORE") &
                    ",arch=" & A_Str &
                    ",addr=" & Natural'Image (I - 1) &
                    ",reg=" & Node.Reg &
                    ",CAP:" & Natural'Image (Cap.Object_ID) & ")");
               when Branch | Call =>
                  Put_Line (F, "PROOF(OP:" &
                    (if Node.Kind = Branch then "BRANCH" else "CALL") &
                    ",arch=" & A_Str &
                    ",addr=" & Natural'Image (I - 1) &
                    ",TARGET:" & Natural'Image (Node.Target.Base_Addr) & ")");
               when Ret =>
                  Put_Line (F, "PROOF(OP:RET,arch=" & A_Str &
                    ",addr=" & Natural'Image (I - 1) & ")");
               when Smc =>
                  Put_Line (F, "PROOF(OP:SMC,arch=AARCH64,addr=" &
                    Natural'Image (I - 1) & ",imm=" & Natural'Image (Node.Imm16) &
                    ",PRIV:EL3_SECURE)");
               when Hvc =>
                  Put_Line (F, "PROOF(OP:HVC,arch=AARCH64,addr=" &
                    Natural'Image (I - 1) & ",imm=" & Natural'Image (Node.Imm16) & ")");
               when Svc =>
                  Put_Line (F, "PROOF(OP:SVC,arch=AARCH64,addr=" &
                    Natural'Image (I - 1) & ",imm=" & Natural'Image (Node.Imm16) & ")");
               when Sys_Reg =>
                  Put_Line (F, "PROOF(OP:SYSREG,arch=AARCH64,addr=" &
                    Natural'Image (I - 1) & ",op=" & Node.Sys_Op &
                    ",gp=" & Node.Gp_Reg & ")");
               when Mov_Imm =>
                  Put_Line (F, "PROOF(OP:MOV_IMM,arch=AARCH64,addr=" &
                    Natural'Image (I - 1) & ",dest=" & Node.Dest_Reg &
                    ",val=" & Natural'Image (Node.Imm_Val) &
                    ",shift=" & Natural'Image (Node.Shift) & ")");
               when Barrier =>
                  Put_Line (F, "PROOF(OP:BARRIER,arch=AARCH64,addr=" &
                    Natural'Image (I - 1) & ",kind=" & Node.Bar_Kind & ")");
               when Arith =>
                  Put_Line (F, "PROOF(OP:ARITH,arch=" & A_Str &
                    ",addr=" & Natural'Image (I - 1) & ",op=" & Node.Opcode & ")");
               when others => null;
            end case;
            I := I + 4;
         end loop;
      else
         while I + 3 <= Last_Idx loop
            Lift_X64 (Data (I .. I + 3), I - 1, Node, Cap);
            case Node.Kind is
               when Unknown => null;
               when Load | Store =>
                  Put_Line (F, "PROOF(OP:" &
                    (if Node.Kind = Load then "LOAD" else "STORE") &
                    ",arch=X86_64,addr=" & Natural'Image (I - 1) &
                    ",reg=" & Node.Reg & ")");
               when Branch | Call =>
                  Put_Line (F, "PROOF(OP:" &
                    (if Node.Kind = Branch then "BRANCH" else "CALL") &
                    ",arch=X86_64,addr=" & Natural'Image (I - 1) &
                    ",TARGET:" & Natural'Image (Node.Target.Base_Addr) & ")");
               when Ret =>
                  Put_Line (F, "PROOF(OP:RET,arch=X86_64,addr=" &
                    Natural'Image (I - 1) & ")");
               when Arith =>
                  Put_Line (F, "PROOF(OP:ARITH,arch=X86_64,addr=" &
                    Natural'Image (I - 1) & ",op=" & Node.Opcode & ")");
               when others => null;
            end case;
            I := I + 4;
         end loop;
      end if;
      Put_Line (F, "LIFT_COMPLETE");
   end Mode_Lift;

   ----------------------------------------------------------------
   -- MAIN: argument parsing, file loading, mode dispatch
   ----------------------------------------------------------------
   type Run_Mode is (M_Strings, M_Elf_Map, M_Entropy, M_Lift, M_Full);

   Mode_Sel : Run_Mode := M_Full;
   In_Path  : access String := null;
   Out_Path : access String := null;
   Force_Arch : Arch_Type := Unknown_Arch;

begin
   -- Parse arguments
   if Argument_Count < 1 then
      Put_Line (Standard_Error,
        "SLEDGE v3.0 — Copyleft Multi-Mode Binary Analyser");
      Put_Line (Standard_Error,
        "Usage: sledge --file <binary> [--mode strings|elf_map|entropy|lift|full]" &
        " [--output <file>] [--arch auto|aarch64|x86_64]");
      Set_Exit_Status (1); return;
   end if;

   declare I : Positive := 1; begin
      while I <= Argument_Count loop
         if Argument (I) = "--file" and I < Argument_Count then
            In_Path := new String'(Argument (I + 1)); I := I + 2;
         elsif Argument (I) = "--mode" and I < Argument_Count then
            declare M : constant String := Argument (I + 1); begin
               if    M = "strings"  then Mode_Sel := M_Strings;
               elsif M = "elf_map"  then Mode_Sel := M_Elf_Map;
               elsif M = "entropy"  then Mode_Sel := M_Entropy;
               elsif M = "lift"     then Mode_Sel := M_Lift;
               elsif M = "full"     then Mode_Sel := M_Full;
               end if;
            end; I := I + 2;
         elsif Argument (I) = "--output" and I < Argument_Count then
            Out_Path := new String'(Argument (I + 1)); I := I + 2;
         elsif Argument (I) = "--arch" and I < Argument_Count then
            if    Argument (I + 1) = "aarch64" then Force_Arch := AArch64;
            elsif Argument (I + 1) = "x86_64"  then Force_Arch := X86_64;
            end if; I := I + 2;
         -- Legacy --lift flag support
         elsif Argument (I) = "--lift" and I < Argument_Count then
            In_Path := new String'(Argument (I + 1));
            Mode_Sel := M_Lift; I := I + 2;
         else I := I + 1;
         end if;
      end loop;
   end;

   if In_Path = null then
      Put_Line (Standard_Error, "Error: --file <binary> required"); return;
   end if;

   -- Load binary
   declare
      File : Ada.Streams.Stream_IO.File_Type;
      S    : Ada.Streams.Stream_IO.Stream_Access;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, In_Path.all);
      S := Ada.Streams.Stream_IO.Stream (File);
      declare
         Buf  : Ada.Streams.Stream_Element_Array (1 .. Max_File);
         Last : Ada.Streams.Stream_Element_Offset;
      begin
         Ada.Streams.Read (S.all, Buf, Last);
         Last_Idx := Natural (Last);
         for I in 1 .. Last_Idx loop
            Data (I) := Unsigned_8 (Buf (Ada.Streams.Stream_Element_Offset (I)));
         end loop;
      end;
      Ada.Streams.Stream_IO.Close (File);
   end;

   Put_Line ("[SLEDGE] Loaded" & Natural'Image (Last_Idx) & " bytes from " & In_Path.all);

   -- Resolve architecture
   declare
      Arch : Arch_Type := (if Force_Arch /= Unknown_Arch then Force_Arch
                           elsif Is_Elf then Detect_Arch
                           else AArch64);
      Out_File : File_Type;
   begin
      if Out_Path /= null then
         Create (Out_File, Ada.Text_IO.Out_File, Out_Path.all);
      else
         Create (Out_File, Ada.Text_IO.Out_File, "/dev/stdout");
      end if;

      Put_Line (Out_File, "SLEDGE_V3(file=" & In_Path.all &
        ",arch=" & Arch_Type'Image (Arch) &
        ",size=" & Natural'Image (Last_Idx) &
        ",mode=" & Run_Mode'Image (Mode_Sel) & ")");

      case Mode_Sel is
         when M_Strings  => Mode_Strings (Out_File);
         when M_Elf_Map  => Mode_Elf_Map (Out_File);
         when M_Entropy  => Mode_Entropy (Out_File);
         when M_Lift     => Mode_Lift (Out_File, Arch);
         when M_Full     =>
            Mode_Strings (Out_File);
            Mode_Elf_Map (Out_File);
            Mode_Entropy (Out_File);
            Mode_Lift (Out_File, Arch);
      end case;

      Close (Out_File);
      Put_Line ("[SLEDGE] Complete.");
   end;
end Sledge;

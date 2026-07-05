-- SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
-- analgapes :: governance/keel/keel_seal.adb
with System;
with Interfaces.C; use Interfaces.C;
package body KEEL_Seal is
   type Byte is mod 256;
   type Digest is array (0 .. Seal_Len - 1) of aliased Byte;
   subtype Raw_Hex is String (1 .. Hex_Len + 1);  -- 128 hex + NUL from C

   function C_Shake (Input : System.Address; N : size_t;
                     Output : System.Address) return int;
   pragma Import (C, C_Shake, "avrs_shake256");
   procedure C_Shake_Hex (Input : System.Address; Output : System.Address);
   pragma Import (C, C_Shake_Hex, "avrs_shake256_hex");

   function Seal (Payload : String) return Hex_String is
      D   : aliased Digest;
      Raw : aliased Raw_Hex := (others => ' ');
      RC  : int;
   begin
      RC := C_Shake (Payload'Address, size_t (Payload'Length), D'Address);
      if RC /= 0 then raise Program_Error with "avrs_shake256 failed"; end if;
      C_Shake_Hex (D'Address, Raw'Address);
      return Raw (1 .. Hex_Len);  -- drop the trailing NUL
   end Seal;
end KEEL_Seal;

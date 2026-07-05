-- SPDX-License-Identifier: ESL-ANCSA-MRA-IndiModSHA-1.0
-- analgapes :: governance/keel/keel_seal.ads
--
-- The seal binds a payload to a SHAKE256-xoflen-64 digest using the SAME
-- C backbone (avrs_shake256) the witness chain uses. Ada calls C via
-- Convention => C. Returns clean 128-char hex (no trailing NUL).

package KEEL_Seal is
   Seal_Len : constant := 64;    -- AVRS_SHAKE_LEN
   Hex_Len  : constant := 128;   -- 64*2, no NUL
   subtype Hex_String is String (1 .. Hex_Len);
   function Seal (Payload : String) return Hex_String;
end KEEL_Seal;

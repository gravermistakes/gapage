import { getEncoding } from "js-tiktoken";
const enc = getEncoding("cl100k_base");
const alphabet = {
  // KANJI primary (operational)
  "源":"origin/source","打":"probe/test","化":"transform","余":"tolerance/margin",
  "率":"rate/yield","断":"decide/gate","連":"coupling/link","関":"abstraction/function",
  "平":"mean/membership","回":"cycle","集":"aggregate/sum","時":"latency/time",
  "了":"conclusion/end","析":"analyze","合":"synthesize","影":"shadow/adversarial",
  "修":"debug/repair","流":"flow/current","核":"core/kernel","推":"infer",
  "相":"phase/state","保":"persist/preserve","見":"observe","読":"parse/read",
  "考":"reason/think","区":"partition","界":"boundary","再":"retry","止":"halt",
  "因":"cause","果":"effect/result",
  // GREEK gap-fillers (only where iconic + no single-token kanji)
  "δ":"anomaly/change","ρ":"correlation",
  // STRUCTURAL control-flow
  "→":"feedforward","←":"feedback","↑":"escalate","↓":"drill-down",
  "−":"discard(FALSE)","✔":"verify/gate-pass","●":"commit","★":"discovery",
  "☆":"candidate","♀":"fuse(copper)","☴":"gentle-probe(Xun)","⟩":"handoff"
};
let bad=[];
for (const [s,m] of Object.entries(alphabet)) if (enc.encode(s).length!==1) bad.push(s+"="+enc.encode(s).length);
console.log("Total: "+Object.keys(alphabet).length);
console.log("Kanji: 31 | Greek: 2 | Structural: 12");
console.log("All single-token: "+(bad.length===0?"YES ✓":"NO: "+bad.join(" ")));

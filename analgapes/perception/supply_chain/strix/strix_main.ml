(* Strix main entry point
 * Copyright (C) 2026 Anja Evermoor
 * GNU GPL v3.0 or later *)

open Strix
open Printf

let () =
  let binary = ref "" in
  let depth = ref 5 in
  let output_file = ref "" in
  let args = Array.to_list Sys.argv |> List.tl in
  let rec parse = function
    | [] -> ()
    | "--depth" :: n :: rest -> depth := int_of_string n; parse rest
    | "--output" :: f :: rest -> output_file := f; parse rest
    | b :: rest when !binary = "" -> binary := b; parse rest
    | _ :: rest -> parse rest
  in
  parse args;
  if !binary = "" then begin
    eprintf "Usage: strix <binary> [--depth <n>] [--output <file>]\n";
    exit 1
  end;
  if not (Sys.file_exists !binary) then begin
    eprintf "[Strix] ERROR: binary not found: %s\n" !binary;
    exit 2
  end;
  eprintf "[Strix] Analyzing: %s (depth=%d)\n" !binary !depth;
  let libs = analyze_recursive !binary !depth [] in
  let libs = dedup_libraries libs in
  eprintf "[Strix] Found %d unique libraries\n" (List.length libs);
  let json = sprintf "{\n  \"target\": \"%s\",\n  \"depth\": %d,\n  \"library_count\": %d,\n  \"libraries\": [\n%s\n  ]\n}"
    !binary !depth (List.length libs)
    (String.concat ",\n" (List.map library_to_json libs))
  in
  if !output_file <> "" then begin
    let oc = open_out !output_file in
    output_string oc json;
    output_char oc '\n';
    close_out oc;
    eprintf "[Strix] Output written to %s\n" !output_file
  end else
    print_string json;
    print_newline ()

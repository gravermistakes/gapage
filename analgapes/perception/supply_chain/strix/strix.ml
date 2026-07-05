(* Strix – ELF dependency parser and symbol resolver
 * Copyright (C) 2026 Anja Evermoor
 * GNU GPL v3.0 or later *)

open Printf

type library = {
  name : string;
  path : string option;
  needed_by : string list;
  symbols : string list;
  version : string option;
}

let read_lines cmd =
  let ic = Unix.open_process_in cmd in
  let rec loop acc =
    try loop (input_line ic :: acc)
    with End_of_file -> acc
  in
  let lines = loop [] in
  let _ = Unix.close_process_in ic in
  List.rev lines

let read_elf_needed binary =
  let cmd = sprintf "readelf -d '%s' 2>/dev/null | grep NEEDED | sed 's/.*\\[//;s/\\]//' " binary in
  read_lines cmd

let resolve_library_path libname =
  let cmd = sprintf "ldconfig -p 2>/dev/null | grep -F '%s' | head -1 | awk '{print $NF}'" libname in
  match read_lines cmd with
  | [p] when p <> "" -> Some p
  | _ ->
    (* fallback: search standard paths *)
    let paths = ["/usr/lib"; "/usr/lib64"; "/lib"; "/lib64";
                 "/usr/lib/x86_64-linux-gnu"; "/usr/lib/aarch64-linux-gnu"] in
    try
      let found = List.find (fun dir ->
        Sys.file_exists (Filename.concat dir libname)
      ) paths in
      Some (Filename.concat found libname)
    with Not_found -> None

let extract_dynamic_symbols path =
  let cmd = sprintf "nm -D '%s' 2>/dev/null | awk '$2 ~ /[TtWw]/ {print $3}'" path in
  List.filter (fun s -> s <> "") (read_lines cmd)

let extract_version path =
  (* try to get SONAME or version string *)
  let cmd = sprintf "readelf -d '%s' 2>/dev/null | grep SONAME | sed 's/.*\\[//;s/\\]//'" path in
  match read_lines cmd with
  | [v] when v <> "" -> Some v
  | _ -> None

let rec analyze_recursive binary depth visited =
  if depth <= 0 || List.mem binary visited then []
  else
    let needed = read_elf_needed binary in
    let visited = binary :: visited in
    List.concat_map (fun libname ->
      let path = resolve_library_path libname in
      let syms = match path with
        | Some p -> extract_dynamic_symbols p
        | None -> []
      in
      let ver = match path with
        | Some p -> extract_version p
        | None -> None
      in
      let lib = {
        name = libname;
        path;
        needed_by = [binary];
        symbols = syms;
        version = ver;
      } in
      let transitive = match path with
        | Some p -> analyze_recursive p (depth - 1) visited
        | None -> []
      in
      lib :: transitive
    ) needed

let dedup_libraries libs =
  let seen = Hashtbl.create 64 in
  List.filter (fun l ->
    if Hashtbl.mem seen l.name then false
    else (Hashtbl.add seen l.name true; true)
  ) libs

let library_to_json l =
  let path_str = match l.path with Some p -> sprintf "\"%s\"" p | None -> "null" in
  let ver_str = match l.version with Some v -> sprintf "\"%s\"" v | None -> "null" in
  let needed_str = String.concat "," (List.map (sprintf "\"%s\"") l.needed_by) in
  sprintf "    {\n      \"name\": \"%s\",\n      \"path\": %s,\n      \"version\": %s,\n      \"needed_by\": [%s],\n      \"symbol_count\": %d,\n      \"symbols_sample\": [%s]\n    }"
    l.name path_str ver_str needed_str
    (List.length l.symbols)
    (String.concat "," (List.map (sprintf "\"%s\"")
      (let rec take n = function [] -> [] | x::xs -> if n <= 0 then [] else x :: take (n-1) xs in
       take 10 l.symbols)))

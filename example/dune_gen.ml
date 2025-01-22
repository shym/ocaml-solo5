let print_rule test exitcode extraifs extralibs =
  let enabled_if out extraifs =
    Printf.fprintf out {|(enabled_if
  |};
    (match extraifs with
    | [] -> ()
    | _ ->
        Printf.fprintf out {|(and
   |};
        List.iter (Printf.fprintf out {|%s
   |}) extraifs);
    Printf.fprintf out {|(= %%{context_name} solo5))|};
    match extraifs with [] -> () | _ -> Printf.fprintf out ")"
  in
  Printf.printf
    {|(executable
 (name %s)
 %a
 (modules %s)
 (link_flags
  :standard
  -cclib
  "-z solo5-abi=%%{env:MODE=hvt}"
  ; Force linking in the manifest
  -cclib
  "-u __solo5_mft1_note")
 (libraries solo5os%a)
 (modes native))

(rule
 (alias runtest)
 %a
 (action
  %a(run "solo5-%%{env:MODE=hvt}" "%%{dep:%s.exe}")%a))

|}
    test enabled_if extraifs test
    (fun out -> List.iter (Printf.fprintf out " %s"))
    extralibs enabled_if extraifs
    (fun out exitcode ->
      match exitcode with
      | None -> ()
      | Some code ->
          Printf.fprintf out {|(with-accepted-exit-codes
   %d
   |} code)
    exitcode test
    (fun out exitcode ->
      match exitcode with None -> () | Some _ -> Printf.fprintf out ")")
    exitcode

let _ =
  print_rule "hello" None [] [];
  print_rule "sysfail" (Some 2) [] [];
  print_rule "config" None [] [];
  print_rule "compilerlibsx86" None
    [ "(>= %{ocaml_version} 5.3.0)"; "(= %{architecture} amd64)" ]
    [ "compiler-libs.optcomp" ]

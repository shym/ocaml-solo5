let print_rule test exitcode extraif extralibs =
  let enabled_if () =
    Printf.printf {|(enabled_if
  |};
    (match extraif with
    | None -> ()
    | Some cnd -> Printf.printf {|(and
   %s
   |} cnd);
    Printf.printf {|(= %%{context_name} solo5))|};
    match extraif with None -> () | Some _ -> Printf.printf ")"
  in
  Printf.printf {|(executable
 (name %s)
 |} test;
  enabled_if ();
  Printf.printf
    {|
 (modules %s)
 (link_flags
  :standard
  -cclib
  "-z solo5-abi=%%{env:MODE=hvt}"
  ; Force linking in the manifest
  -cclib
  "-u __solo5_mft1_note")
 (libraries solo5os|}
    test;
  List.iter (Printf.printf " %s") extralibs;
  Printf.printf {|)
 (modes native))

(rule
 (alias runtest)
 |};
  enabled_if ();
  Printf.printf {|
 (action
  |};
  (match exitcode with
  | None -> ()
  | Some x -> Printf.printf {|(with-accepted-exit-codes
   %d
   |} x);
  Printf.printf {|(run "solo5-%%{env:MODE=hvt}" "%%{dep:%s.exe}")))%s%s|} test
    (match exitcode with None -> "" | Some _ -> ")")
    {|

|}

let _ =
  print_rule "hello" None None [];
  print_rule "sysfail" (Some 2) None [];
  print_rule "config" None None [];
  print_rule "compilerlibsx86" None
    (Some "(>= %{ocaml_version} 5.3.0) (= %{architecture} amd64)")
    [ "compiler-libs.optcomp" ]

let print_rule test exitcode extraif =
  Printf.printf {|(test
 (name %s)
 (enabled_if
  |} test;
  (match extraif with
  | None -> ()
  | Some cnd -> Printf.printf {|(and
   %s
   |} cnd);
  Printf.printf {|(= %%{context_name} solo5))|};
  (match extraif with None -> () | Some _ -> Printf.printf ")");
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
 (libraries solo5os)
 (action
  |}
    test;
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
  print_rule "hello" None None;
  print_rule "sysfail" (Some 2) None

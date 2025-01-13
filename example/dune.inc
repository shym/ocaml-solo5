(test
 (name hello)
 (enabled_if
  (= %{context_name} solo5))
 (modules hello)
 (link_flags
  :standard
  -cclib
  "-z solo5-abi=%{env:MODE=hvt}"
  ; Force linking in the manifest
  -cclib
  "-u __solo5_mft1_note")
 (libraries solo5os)
 (action
  (run "solo5-%{env:MODE=hvt}" "%{dep:hello.exe}")))

(test
 (name sysfail)
 (enabled_if
  (= %{context_name} solo5))
 (modules sysfail)
 (link_flags
  :standard
  -cclib
  "-z solo5-abi=%{env:MODE=hvt}"
  ; Force linking in the manifest
  -cclib
  "-u __solo5_mft1_note")
 (libraries solo5os)
 (action
  (with-accepted-exit-codes
   2
   (run "solo5-%{env:MODE=hvt}" "%{dep:sysfail.exe}"))))

(test
 (name config)
 (enabled_if
  (= %{context_name} solo5))
 (modules config)
 (link_flags
  :standard
  -cclib
  "-z solo5-abi=%{env:MODE=hvt}"
  ; Force linking in the manifest
  -cclib
  "-u __solo5_mft1_note")
 (libraries solo5os)
 (action
  (run "solo5-%{env:MODE=hvt}" "%{dep:config.exe}")))

(test
 (name compilerlibsx86)
 (enabled_if
  (and
   (>= %{ocaml_version} 5.3.0)
   (= %{context_name} solo5)))
 (modules compilerlibsx86)
 (link_flags
  :standard
  -cclib
  "-z solo5-abi=%{env:MODE=hvt}"
  ; Force linking in the manifest
  -cclib
  "-u __solo5_mft1_note")
 (libraries solo5os)
 (action
  (run "solo5-%{env:MODE=hvt}" "%{dep:compilerlibsx86.exe}")))


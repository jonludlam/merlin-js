module Utils : sig
  val get_el_by_id : string -> Brr.El.t
  val get_full_doc : Code_mirror.State.EditorState.t -> string
end

val ocaml : Code_mirror.Extension.t
(** An extension providing OCaml syntax highlighting *)

module type Config = sig
  val worker_url : string
  (** The url of the worker javascript file *)

  val cmis : Js_top_worker_rpc.Toplevel_api_gen.cmis
  (** CMIs are required for merlin to work correctly. These can either be
      provided statically or provided as a list of URLs from which the CMIs can
      be downloaded. If using URLs, these will only be downloaded on demand. *)
end

val autocomplete : Js_top_worker_client_fut.rpc -> Code_mirror.Extension.t
(** An extension providing completions when typing *)

val tooltip_on_hover : Js_top_worker_client_fut.rpc -> Code_mirror.Extension.t
(** An extension providing type-information when hovering code *)

val linter : Js_top_worker_client_fut.rpc -> Code_mirror.Extension.t
(** An extension that highlights errors and warnings in the code *)

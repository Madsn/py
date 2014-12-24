(defmodule py
  (export all))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Application functions
;;;
(defun start ()
  (let* ((python-path (py-config:get-python-path))
         (`#(ok ,pid) (python:start `(#(python_path ,python-path)))))
    (erlang:register (py-config:get-server-pid-name) pid)
    (module 'lfe 'init.setup)
    #(ok started)))

(defun stop ()
  (python:stop (pid))
  (erlang:unregister (py-config:get-server-pid-name))
  #(ok stopped))

(defun restart ()
  (stop)
  (start)
  #(ok restarted))

(defun pid ()
  (erlang:whereis (py-config:get-server-pid-name)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; REPL functions
;;;
(defun dir (obj)
  (lfe_io:format "~p~n"
                 `(,(module 'builtins 'dir `(,obj)))))

(defun vars (obj)
  (lfe_io:format "~p~n"
                 `(,(module 'builtins 'vars `(,obj)))))

(defun type (obj)
  (let* ((class (attr obj '__class__))
         (repr (module 'builtins 'repr `(,class))))
    (list_to_atom (cadr (string:tokens repr "'")))))

(defun repr
  ((`#(,opaque ,lang ,data))
    (io:format "#(~s ~s~n  #B(~ts))~n"
               `(,opaque ,lang ,data))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Call functions
;;;

;; ErlPort Calls
;;
(defun module (mod func)
  (module mod func '()))

(defun module (mod func args)
  (python:call (pid) mod func args))

(defun module (mod func args kwargs)
  (python:call (pid) mod func args kwargs))

;; Creating Python class instances
;;
(defun init (module class)
  (init module class '() '()))

(defun init (module class args)
  (init module class args '()))

(defun init (module class args kwargs)
  (func module class args kwargs))

;; Python object and module constants
;;
(defun const
  ((mod attr-name) (when (is_atom mod))
    (let* ((pid (pid))
           (attr (atom_to_binary attr-name 'latin1)))
      ;; Now call to the 'const' function in the Python module 'lfe.obj'
      (module 'lfe 'obj.const `(,mod ,attr))))
  ((obj type)
    (method obj (list_to_atom (++ "__"
                                  (atom_to_list type)
                                  "__")))))


(defun const (mod func type)
  (module mod (list_to_atom (++ (atom_to_list func)
                                "."
                                "__"
                                (atom_to_list type)
                                "__"))))

;; Python object attributes
;;
(defun attr
  ((obj attr-name) (when (is_list attr-name))
    (attr obj (list_to_atom attr-name)))
  ((obj attr-name) (when (is_atom attr-name))
    (let* ((pid (pid))
           (attr (atom_to_binary attr-name 'latin1)))
      ;; Now call to the 'attr' function in the Python module 'lfe.obj'
      (module 'lfe 'obj.attr `(,obj ,attr)))))

;; Python method calls
;;
(defun method (obj method-name)
  (method obj method-name '() '()))

(defun method (obj method-name args)
  (method obj method-name args '()))

(defun method (obj method-name args kwargs)
  (general-call obj method-name args kwargs 'obj.call_method))

;; Python module function and function object calls
;;
(defun func (func-name)
    (func func-name '() '()))

(defun func
  ((module func-name) (when (is_atom module))
    (func module func-name '() '()))
  ((func-name args) (when (is_list args))
    (func func-name args '())))

(defun func
  ((module func-name args) (when (is_atom module))
    (func module func-name args '()))
  ((func-name args raw-kwargs) (when (is_list args))
    (let ((kwargs (py-util:proplist->binary raw-kwargs)))
      ;; Now call to the 'call_callable' function in the Python
      ;; module 'lfe.obj'
      (module 'lfe 'obj.call_callable `(,func-name ,args ,kwargs)))))

(defun func (module func-name args kwargs)
  ;; Now call to the 'call_func' function in the Python module 'lfe.obj'
  (general-call (atom_to_binary module 'latin1)
                   func-name
                   args
                   kwargs
                   'obj.call_func))

(defun general-call (obj attr-name args raw-kwargs type)
  (let* ((attr (atom_to_binary attr-name 'latin1))
         (kwargs (py-util:proplist->binary raw-kwargs)))
    (module 'lfe type `(,obj ,attr ,args ,kwargs))))

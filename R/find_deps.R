# =====================================================================
# Symbol/dependency tracing
# =====================================================================

#' Find all symbols used in a function or language object.
#'
#' @param x A language object or function.
#'
#' @return A character vector of the symbols used in the object.
#'
#' @examples
#' # Find all symbols used in the lm function
#' find_symbols(utils::install.packages)
#'
#' # Does not find names of arguments
#' find_symbols(quote(foo(a = A)))
#' #> [1] "A"   "foo"
#'
#' find_symbols(quote(function(x = X) NULL))
#' #> [1] "function" "X"
#'
#' @export
find_symbols <- function(x) {
  sym_table <- find_symbols_impl(x)
  ls(sym_table, all.names = TRUE)
}

# Recurses over a function or language object and returns an environment where
# every symbol in the object is represented by a key in the environment.
# `sym_table` is an environment which is used for its ability to store keys
# quickly. For example, if a symbol `x` is found, a entry named `x` is added to
# `sym_table`, as in `sym_table[["x"]]`. (The value is not used, only the key.)
# Recursive calls to this function pass along `sym_table`; because it is a
# reference object, it can be mutated from anywhere -- this is much faster than
# each recursive call collecting the results and then calling
# `unique(unlist(res)))`.
find_symbols_impl <- function(x, sym_table = new.env()) {
  if (is.symbol(x)) {
    x_str <- as.character(x)
    if (nzchar(x_str)) {
      sym_table[[x_str]] <- TRUE
    }

  } else if (is.language(x) || is.pairlist(x)) {
    # Function parameters are pairlists
    walk(x, find_symbols_impl, sym_table)

  } else if (is.function(x)) {
    find_symbols_impl(body(x), sym_table)
    find_symbols_impl(formals(x), sym_table)

  } else if (is.atomic(x)) {
    # Ignore atomic types; they can't contain symbols.

  } else {
    # message(
    #   "Note: don't know how to handle object with class ",
    #   paste(class(x), collapse = ", ")
    # )
  }

  # Note that this return value is only actually used by the `find_symbols()`,
  # which calls this function; it is not used by the recursive calls to this
  # function.
  sym_table
}

#' Given a package namespace or an environment, find all internal symbols used
#' by each function
#'
#' @description
#'
#' `find_internal_symbols()` finds all the objects in the given package
#' namespace (or environment), then, for each function in the environment, it
#' finds all symbols in the function (by calling [find_symbols()], and then it
#' filters the symbols so that only symbols referring to objects in the
#' environment/namespace remain.
#'
#' `find_internal_deps()` does the same, and then for each function, it
#' considers each (internal) symbol as a dependency and recursively finds all
#' dependencies. So for a given function in the environment,
#' `find_internal_deps()` finds the internal dependencies needed for that
#' function.
#'
#' @return A named list, where the name of each element is the name of each
#'   object in `env`, and the value is a character vector of strings, where each
#'   string is the name of an object in the environment.
#'
#' @param env A string naming a package, or an environment.
#'
#' @examples
#' # By default, find symbols internal to the staticimports package
#' find_internal_symbols()
#'
#' # Find all symbols internal to the utils package
#' find_internal_symbols("utils")
#'
#' @export
find_internal_symbols <- function(env = "staticimports") {
  if (is_string(env)) env <- getNamespace(env)

  # Find the symbols used by each object in the environment.
  obj_symbols <- lapply(env, find_symbols)
  # Get names of all the objects in this environment
  obj_names <- ls(env, all.names = TRUE)

  # For each object's symbols, filter so that only symbols naming objects in
  # this environment remain.
  obj_symbols <- lapply(obj_symbols, function(y) y[y %in% obj_names])
  obj_symbols
}


#' @rdname find_internal_symbols
#' @export
find_internal_deps <- function(env = "staticimports") {
  if (is_string(env)) env <- getNamespace(env)

  obj_symbols <- find_internal_symbols(env)

  res <- lapply(names(obj_symbols), find_internal_deps_one, obj_symbols)
  names(res) <- names(obj_symbols)
  res
}


find_internal_deps_one <- function(x, sym_table) {
  deps <- find_internal_deps_one_impl(x, sym_table)
  ls(deps, all.names = TRUE)
}

find_internal_deps_one_impl <- function(x, sym_table, table = new.env()) {
  children_names <- sym_table[[x]]

  for (child_name in children_names) {
    if (!exists(child_name, envir = table, inherits = FALSE)) {
      table[[child_name]] <- TRUE
      find_internal_deps_one_impl(child_name, sym_table, table)
    }
  }

  table
}


is_string <- function(x) {
  is.character(x) && length(x) == 1 && !is.na(x)
}

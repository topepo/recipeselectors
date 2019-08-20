#' mRMR feature selection recipe
#'
#' Initial function - simple wrapper around add_step
#'
#' @param recipe 	A recipe object. The step will be added to the sequence of operations
#'  for this recipe
#' @param ... One or more selector functions to choose which variables are affected by the
#'   step. See selections() for more details. For the tidy method, these are not currently
#'   used
#' @param role Not used by this step since no new variables are created
#' @param trained A logical to indicate if the quantities for preprocessing have been
#'   estimated
#' @param k numeric, if an integer value is supplied, then this represents the number of best
#' scoring features to select, if a decimal between 0 and 1 is supplied then then top percentile
#' of features are selected
#' @param threads integer, number of threads to use for processing, default = 0 uses all
#'   available threads
#' @param to_retain character, names of features to retain
#' @param skip A logical. Should the step be skipped when the recipe is baked by
#'   bake.recipe()? While all operations are baked when prep.recipe() is run, some
#'   operations may not be able to be conducted on new data (e.g. processing the outcome
#'   variable(s)). Care should be taken when using skip = TRUE as it may affect the
#'   computations for subsequent operations
#' @param id 	A character string that is unique to this step to identify it
#'
#' @return a step_mrmr object
#' @export
#' @importFrom recipes ellipse_check rand_id add_step
step_mrmr <- function(
  recipe, ...,
  target = NULL,
  role = NA,
  trained = FALSE,
  k = NULL,
  threads = 0,
  to_retain = NULL,
  skip = FALSE,
  id = rand_id("mrmr")) {

  terms <- ellipse_check(...)

  add_step(
    recipe,
    step_mrmr_new(
      terms = terms,
      trained = trained,
      target = target,
      role = role,
      k = k,
      threads = threads,
      to_retain = to_retain,
      skip = skip,
      id = id
    )
  )
}

# wrapper around 'step' function that sets the class of new step objects
#' @export
step_mrmr_new <- function(terms, role, trained, target, k, threads, to_retain, skip, id) {
    step(
      subclass = "mrmr", # set class of new objects to 'step_mrmr'
      terms = terms,
      role = role,
      trained = trained,
      target = target,
      k = k,
      threads = threads,
      to_retain = to_retain,
      skip = skip,
      id = id
    )
  }

# define the estimation procedure
# x is the step_mrmr object
# training is a tibble that has the training set data
# info is a tibble that contains information on the current set of data
# this is updated each time as each step function is evaluated by its prep method
#' @export
#' @importFrom praznik MRMR
#' @importFrom recipes terms_select
prep.step_mrmr <- function(x, training, info = NULL, ...) {

  # first translate the terms argument into column name
  # this term should refer to the response variable for step_mrmr
  col_names <- terms_select(terms = x$terms, info = info)
  target_name <- x$target

  # perform mrmr using all features
  X <- training[, col_names]
  y <- training[[target_name]]

  # some checks
  if (any(sapply(X, class)) == "factor")
    stop("mrmr step method cannot be applied to factors")

    # perform mrmr using all features
  mi <- MRMR(X, y, length(col_names), x$threads)

  # select top scoring features
  if (is.null(x$k))
    x$k <- length(col_names)

  if (x$k %% 1 != 0)
    x$k <- ceiling(length(col_names) * x$k)

  to_retain  <- c(names(mi$selection)[1:x$k], target_name)

  ## Use the constructor function to return the updated object.
  ## Note that `trained` is set to TRUE
  step_mrmr_new(
    terms = x$terms,
    trained = TRUE,
    role = x$role,
    target = target_name,
    k = x$k,
    threads = x$threads,
    to_retain = to_retain,
    skip = x$skip,
    id = x$id
  )
}

# prep method does not apply the method, it only calculates any required data
# the bake method is defined to do this
# object is the updated step function that has been through the corresponding prep code
# new_data is a tibble of data to be processed
#' @export
#' @importFrom tibble as_tibble
bake.step_mrmr <- function(object, new_data, ...) {

  new_data <- new_data[, (colnames(new_data) %in% object$to_retain)]

  ## Always convert to tibbles on the way out
  as_tibble(new_data)
}
#' Load an existing fastText trained model
#'
#' Load and return a pointer to an existing model which will be used in other functions of this package.
#' @param path path to the existing model
#' @examples
#'
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_classification_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' @export
load_model <- function(path) {
  if (!grepl("\\.(bin|ftz)$", path)) {
    message("add .bin extension to the path")
    path <- paste0(path, ".bin")
  }
  model <- new(fastrtext)
  model$load(path)
  model
}

#' Export hyper parameters
#'
#' Retrieve hyper parameters used to train the model
#' @param model trained `fastText` model
#' @return [list] containing each parameter
#' @examples
#'
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_classification_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' print(head(get_parameters(model), 5))
#'
#' @export
get_parameters <- function(model) {
  model$get_parameters()
}

#' Get list of known words
#'
#' Get a [character] containing each word seen during training.
#' @param model trained `fastText` model
#' @return [character] containing each word
#' @examples
#'
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_classification_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' print(head(get_dictionary(model), 5))
#'
#' @export
get_dictionary <- function(model) {
  model$get_dictionary()
}

#' Get list of labels (supervised model)
#'
#' Get a [character] containing each label seen during training.
#' @param model trained `fastText` model
#' @return [character] containing each label
#' @importFrom assertthat assert_that
#' @examples
#'
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_classification_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' print(head(get_labels(model), 5))
#'
#' @export
get_labels <- function(model) {
  param <- model$get_parameters()
  assert_that(param$model_name == "supervised",
              msg = "This is not a supervised model.")
  model$get_labels()
}

#' Get predictions (for supervised model)
#'
#' Apply the trained  model to new sentences.
#' Average word embeddings and search most similar `label` vector.
#' @param object trained `fastText` model
#' @param sentences [character] containing the sentences
#' @param k will return the `k` most probable labels (default = 1)
#' @param unlock_empty_predictions [logical] to avoid crash when some predictions are not provided for some sentences because all their words have not been seen during training. This parameter should only be set to [TRUE] to debug.
#' @param ... not used
#' @return [data.frame] containing for each sentence the probability to be associated with `k` labels.
#' @examples
#'
#' library(fastrtext)
#' data("test_sentences")
#' model_test_path <- system.file("extdata", "model_classification_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' sentence <- test_sentences[1, "text"]
#' print(predict(model, sentence))
#'
#' @importFrom assertthat assert_that is.flag is.count
#' @export
predict.Rcpp_fastrtext <- function(object, sentences, k = 1, ...) {
  assert_that(is.count(k))
  
  predictions <- object$predict(sentences, k)

  predictions
  
}

#' Get word embeddings
#'
#' Return the vector representation of provided words (unsupervised training)
#' or provided labels (supervised training).
#'
#' @examples
#'
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_unsupervised_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' get_word_vectors(model, c("introduction", "we"))
#'
#' @param model trained `fastText` model
#' @param words [character] of words. Default: return every word from the dictionary.
#' @return [matrix] containing each word embedding as a row and `rownames` are populated with word strings.
#' @importFrom assertthat assert_that
#' @export
get_word_vectors <- function(model, words = get_dictionary(model)) {
  assert_that(is.character(words))
  model$get_vectors(words)
}

#' Execute command on `fastText` model (including training)
#'
#' Use the same commands than the one to use for the command line.
#'
#' @param commands [character] of commands
#' @examples
#' \dontrun{
#' # Supervised learning example
#' library(fastrtext)
#'
#' data("train_sentences")
#' data("test_sentences")
#'
#' # prepare data
#' tmp_file_model <- tempfile()
#'
#' train_labels <- paste0("__label__", train_sentences[,"class.text"])
#' train_texts <- tolower(train_sentences[,"text"])
#' train_to_write <- paste(train_labels, train_texts)
#' train_tmp_file_txt <- tempfile()
#' writeLines(text = train_to_write, con = train_tmp_file_txt)
#'
#' test_labels <- paste0("__label__", test_sentences[,"class.text"])
#' test_texts <- tolower(test_sentences[,"text"])
#' test_to_write <- paste(test_labels, test_texts)
#'
#' # learn model
#' execute(commands = c("supervised", "-input", train_tmp_file_txt,
#'                      "-output", tmp_file_model, "-dim", 20, "-lr", 1,
#'                      "-epoch", 20, "-wordNgrams", 2, "-verbose", 1))
#'
#' model <- load_model(tmp_file_model)
#' predict(model, sentences = test_sentences[1, "text"])
#'
#' # Unsupervised learning example
#' library(fastrtext)
#'
#' data("train_sentences")
#' data("test_sentences")
#' texts <- tolower(train_sentences[,"text"])
#' tmp_file_txt <- tempfile()
#' tmp_file_model <- tempfile()
#' writeLines(text = texts, con = tmp_file_txt)
#' execute(commands = c("skipgram", "-input", tmp_file_txt, "-output", tmp_file_model, "-verbose", 1))
#'
#' model <- load_model(tmp_file_model)
#' dict <- get_dictionary(model)
#' get_word_vectors(model, head(dict, 5))
#' }
#' @export
execute <- function(commands) {
  model <- new(fastrtext)
  model$execute(c("fasttext", commands))
}

#' Distance between two words
#'
#' Distance is equal to `1 - cosine`
#' @param model trained `fastText` model. Null if train a new model.
#' @param w1 first word to compare
#' @param w2 second word to compare
#' @return a `scalar` with the distance
#'
#' @examples
#'
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_unsupervised_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' get_word_distance(model, "time", "timing")
#'
#' @importFrom assertthat assert_that is.string
#' @export
get_word_distance <- function(model, w1, w2) {
  assert_that(is.string(w1))
  assert_that(is.string(w2))
  embeddings <- get_word_vectors(model, c(w1, w2))
  1 - crossprod(embeddings[1, ], embeddings[2, ]) /
    sqrt(crossprod(embeddings[1, ]) * crossprod(embeddings[2, ]))
}

#' Hamming loss
#'
#' Compute the hamming loss. When there is only one category, this measure the accuracy.
#' @param labels list of labels
#' @param predictions list returned by the predict command (including both the probability and the categories)
#' @return a `scalar` with the loss
#'
#' @examples
#'
#' library(fastrtext)
#' data("test_sentences")
#' model_test_path <- system.file("extdata", "model_classification_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' sentences <- test_sentences[, "text"]
#' test_labels <- test_sentences[, "class.text"]
#' predictions <- predict(model, sentences)
#' get_hamming_loss(as.list(test_labels), predictions)
#'
#' @importFrom assertthat assert_that
#' @export
get_hamming_loss <- function(labels, predictions) {
  diff <- function(a, b) {
    common <- union(a, b)
    difference <- setdiff(union(a, b), intersect(a, b))
    distance <- length(difference) / length(common)
    1 - distance
  }
  assert_that(is.list(labels))
  assert_that(is.list(predictions))
  assert_that(length(labels) == length(predictions))
  prediction_categories <- lapply(predictions, names)
  mean(mapply(diff, prediction_categories, labels, USE.NAMES = FALSE))
}

#' Print help
#'
#' Print command information, mainly to use with [execute()] `function`.
#'
#' @examples
#' \dontrun{
#' print_help()
#' }
#'
#' @export
print_help <- function() {
  model <- new(fastrtext)
  model$print_help()
  rm(model)
}

#' Get nearest neighbour vectors
#'
#' Find the `k` words with the smallest distance.
#' First execution can be slow because of precomputation.
#' Search is done linearly, if your model is big you may want to use an approximate neighbour algorithm from other R packages (like RcppAnnoy).
#'
#' @param model trained `fastText` model. Null if train a new model.
#' @param word reference word
#' @param k [integer] defining the number of results to return
#' @return [numeric] with distances with [names] as words
#'
#' @examples
#'
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_unsupervised_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' get_nn(model, "time", 10)
#'
#' @importFrom assertthat assert_that is.string is.number
#' @export
get_nn <- function(model, word, k) {
  assert_that(is.string(word))
  assert_that(is.number(k))
  vec <- model$get_vector(word)
  model$get_nn_by_vector(vec, word, k)
}

#' Get analogy
#'
#' From Mikolov paper
#' Based on related move of a vector regarding a basis.
#' King is to Quenn what a man is to ???
#' w1 - w2 + w3
#' @param model trained `fastText` model. [NULL] if train a new model.
#' @param w1 1st word, basis
#' @param w2 2nd word, move
#' @param w3 3d word, new basis
#' @param k number of words to return
#' @return a [numeric] with distances and [names] are words
#' @examples
#'
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_unsupervised_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' get_analogies(model, "experience", "experiences", "result")
#'
#' @importFrom assertthat assert_that is.string is.number
#' @export
get_analogies <- function(model, w1, w2, w3, k = 1) {
  assert_that(is.string(w1))
  assert_that(is.string(w2))
  assert_that(is.string(w3))
  assert_that(is.number(k))

  vec <- model$get_vector(w1) - model$get_vector(w2) + model$get_vector(w3)
  model$get_nn_by_vector(vec, c(w1, w2, w3), k)
}

#' Add tags to documents
#'
#' Add tags in the `fastText`` format.
#' This format is require for the training step.
#'
#' @param documents texts to learn
#' @param tags labels provided as a [list] or a [vector]. There can be 1 or more per document.
#' @param prefix [character] to add in front of tag (`fastText` format)
#' @return [character] ready to be written in a file
#'
#' @examples
#' library(fastrtext)
#' tags <- list(c(1, 5), 0)
#' documents <- c("this is a text", "this is another document")
#' add_tags(documents = documents, tags = tags)
#'
#' @importFrom assertthat assert_that is.string
#' @export
add_tags <- function(documents, tags, prefix = "__label__") {
  assert_that(is.character(documents))
  assert_that(is.string(prefix))
  assert_that(length(documents) == length(tags))

  tags_to_include <- sapply(tags, FUN = function(t) paste0(prefix, t, collapse = " "))
  paste(tags_to_include, documents)
}

#' Get sentence embedding
#'
#' Sentence is splitted in words (using space characters), and word embeddings are averaged.
#'
#' @param model `fastText` model
#' @param sentences [character] containing the sentences
#' @examples
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_unsupervised_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' m <- get_sentence_representation(model, "this is a test")
#' print(m)
#' @importFrom assertthat assert_that
#' @export
get_sentence_representation <- function(model, sentences) {
  assert_that(is.character(sentences))
  m <- sapply(X = sentences, FUN = function(sentence) model$get_sentence_vector(sentence), USE.NAMES = FALSE)
  t(m)
}

#' Retrieve word IDs
#'
#' Get ID of words in the dictionary
#' @param model `fastText` model
#' @param words [character] containing words to retrieve IDs
#' @return [numeric] of ids
#' @examples
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_unsupervised_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' ids <- get_word_ids(model, c("this", "is", "a", "test"))
#'
#' # print positions
#' print(ids)
#' # retrieve words in the dictionary using the positions retrieved
#' print(get_dictionary(model)[ids])
#' @importFrom assertthat assert_that
#' @export
get_word_ids <- function(model, words) {
  assert_that(is.character(words))
  model$get_word_ids(words)
}

#' Tokenize text
#'
#' Separate words in a text using space characters
#' @param model `fastText` model
#' @param texts a [character] containing the documents
#' @return a [list] of [character] containing words
#' @examples
#' library(fastrtext)
#' model_test_path <- system.file("extdata", "model_unsupervised_test.bin", package = "fastrtext")
#' model <- load_model(model_test_path)
#' tokens <- get_tokenized_text(model, "this is a test")
#' print(tokens)
#' tokens <- get_tokenized_text(model, c("this is a test 1", "this is a second test!"))
#' print(tokens)
#' @importFrom assertthat assert_that is.string
#' @export
get_tokenized_text <- function(model, texts){
  assert_that(is.character(texts))
  lapply(texts, FUN = function(text) model$tokenize(text))
}

globalVariables(c("new"))

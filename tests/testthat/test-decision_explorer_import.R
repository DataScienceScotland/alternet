test_that("import_from_decision_explorer_xml works", {
  expect_equal(alternet::example_network,
               import_from_decision_explorer_xml("inst/extdata/example_network.mdx"))
})

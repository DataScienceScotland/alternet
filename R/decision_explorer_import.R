#' Imports a Decision Explorer xml-formatted model as a network, converting to a standardised R format
#'
#' @param filepath The filepath of the Decision Explorer xml file
#' @param scaling Factor to scale the coordinates down by

#' @return A named list with a tibble containing information about nodes, and a tibble containing information about edges
#' @examples import_from_decision_explorer_xml("inst/extdata/example_network.mdx", scaling = 5)
#' @export
import_from_decision_explorer_xml = function(filepath, scaling = 5) {
  xml_data = xml2::read_xml(filepath) # read the data into an xml document

  nodes = xml_data %>%
    get_node_info_de() %>%
    dplyr::mutate(name = stringr::str_c("elem-", refno), # create a unique id for the node, based on the refno
                  id = stringr::str_c("node-", refno)) %>%
    # rescale coordinates to keep layout nice
    dplyr::mutate(x = x / scaling,
                  y = -y / scaling) %>%  # also reverse y direction as decision explorer has origin in bottom left rather than top left
    dplyr::select(name, refno, label, type, id, x, y) %>%
    dplyr::mutate(description = as.character(NA),
                  tags = as.character(NA))

  edges = xml_data %>%
    get_edge_info_de() %>%
    dplyr::mutate_at(c("from", "to"), ~stringr::str_c("elem-", .)) %>% # specifying from and to nodes by id instead of refno
    dplyr::mutate(refno = 1:nrow(.),# assign a unique refno for the edge
                  name = stringr::str_c("conn-", refno),
                  id = stringr::str_c("edge-", refno), # create a unique id for the edge, based on the refno
                  curvature = as.double(NA),
                  description = as.character(NA),
                  weight = 1) %>%
    dplyr::select(name, refno, polarity, from, to, id, curvature, description, weight)

  node_styles = xml_data %>%
    get_node_style_info_de()

  list(nodes = nodes, edges = edges, node_styles = node_styles) # return the node, edge and style information
}

#' Extracts node information from Decision Explorer xml (as created by xml2::read_xml())
#'
#' @param raw_xml xml document read from the model file

#' @return A tibble containing information about nodes
#' @examples xml2::read_xml("example_network.mdx") %>% get_node_info_de()
get_node_info_de = function(raw_xml) {
  nodes_xml = xml2::xml_find_all(raw_xml, ".//concept") # Navigate to the node elements

  layout_xml = xml2::xml_find_all(raw_xml, ".//position") # Navigate to the position elements

  nodes = tibble::tibble(refno = xml2::xml_attr(nodes_xml, "id") %>% as.integer(),
                         label = xml2::xml_text(nodes_xml),
                         type = xml2::xml_attr(nodes_xml, "style") %>% dplyr::na_if("standard"))

  layout = tibble::tibble(x = xml2::xml_attr(layout_xml, "x") %>% as.double(),
                          y = xml2::xml_attr(layout_xml, "y") %>% as.double(),
                          refno = xml2::xml_attr(layout_xml, "concept") %>% as.integer()) %>%
    dplyr::distinct(refno, .keep_all = TRUE)

  nodes %>%
    dplyr::left_join(layout, by = "refno")
}

#' Extracts edge information from Decision Explorer xml (as created by xml2::read_xml())
#'
#' @param raw_xml xml document read from the model file

#' @return A tibble containing information about edges
#' @examples xml2::read_xml("example_network.mdx") %>% get_edge_info_de()
get_edge_info_de = function(raw_xml) {
  edges_xml = xml2::xml_find_all(raw_xml, ".//link") # Navigate to the edge elements

  tibble::tibble(from = xml2::xml_attr(edges_xml, "linkfrom"),
                 to = xml2::xml_attr(edges_xml, "linkto"),
                 polarity = xml2::xml_attr(edges_xml, "sign"))
}

#' Extracts node style information from Decision Explorer xml (as created by xml2::read_xml())
#'
#' @param raw_xml xml document read from the model file

#' @return A tibble containing information about styles
#' @examples xml2::read_xml("example_network.mdx") %>% get_node_style_info_de()
get_node_style_info_de = function(raw_xml) {
  styles_xml = xml2::xml_find_all(raw_xml, ".//conceptstyle") # Navigate to the edge elements

  tibble::tibble(type = xml2::xml_attr(styles_xml, "name") %>% dplyr::na_if("standard"),
                 font_colour = rgb(xml2::xml_attr(styles_xml, "redpercent"),
                                   xml2::xml_attr(styles_xml, "greenpercent"),
                                   xml2::xml_attr(styles_xml, "bluepercent"),
                                   maxColorValue = 100) %>%
                   stringr::str_to_lower(),
                 font_weight = xml2::xml_attr(styles_xml, "bold") %>% dplyr::recode(`1` = "bold", `0` = as.character(NA)))
}

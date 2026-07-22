library(opr)
library(DBI)
library(readr)
library(bit64)

# connect to bigquery DMD dataset
con <- connect_bq(dataset = "dmd", credentials_var = "OP_CREDENTIALS")

# create function to read codelist with correct column types
read_codelist <- function(path) {
  cl <- read_csv(
    path,
    col_types = cols(
      .default = col_character()
    ),
    show_col_types = FALSE
  )
  # opensafely-oxycodone-subcutaneous-dmd uses "type" instead of "dmd_type"
  if (!"dmd_type" %in% names(cl) && "type" %in% names(cl)) {
    cl$dmd_type <- cl$type
    cl$type <- NULL
  } else if (!"dmd_type" %in% names (cl) && !"type" %in% names (cl)) {
    cl$dmd_type <- case_when(
      grepl("AMP", term) ~ "AMP",
      grepl("VMP", term) ~ "VMP"
    )
  }
  cl
}

# convert dmd covdes to bigint for SQL queries
as_int64 <- function(codes) {
  as.integer64(codes[!is.na(codes) & codes != ""])
}

# convert VMP previous to codes to lookup_id for SQL queries
vmp_lookup_id <- function(term, code) {
  ifelse(
    grepl("VMP previous to [0-9]+", term),
    sub(".*VMP previous to ([0-9]+).*", "\\1", term),
    code
  )
}

# convert vector of codes to SQL IN clause
in_clause <- function(codes) {
  paste(as.character(as_int64(codes)), collapse = ",")
}

# build SQL query to fetch uom for VMPs
build_vmp_uom_sql <- function(ids) {
  paste0(
    "SELECT\n",
    "  CAST(vmp.id AS STRING) AS lookup_id,\n",
    "  uom.descr AS uom\n",
    "FROM `ebmdatalab.dmd.vmp` vmp\n",
    "LEFT JOIN `dmd.unitofmeasure` uom ON vmp.unit_dose_uom = uom.cd\n",
    "WHERE vmp.id IN (",
    in_clause(ids),
    ")\n"
  )
}

# build SQL query to fetch uom for AMPs
build_amp_uom_sql <- function(ids) {
  paste0(
    "SELECT\n",
    "  CAST(amp.id AS STRING) AS lookup_id,\n",
    "  uom.descr AS uom\n",
    "FROM `ebmdatalab.dmd.amp` amp\n",
    "LEFT JOIN `ebmdatalab.dmd.vmp` vmp ON amp.vmp = vmp.id\n",
    "LEFT JOIN `dmd.unitofmeasure` uom ON vmp.unit_dose_uom = uom.cd\n",
    "WHERE amp.id IN (",
    in_clause(ids),
    ")\n"
  )
}

# fetch uom for given ids using provided SQL builder function
fetch_uom <- function(ids, build_sql) {
  ids <- unique(ids[!is.na(ids) & ids != ""])
  if (length(ids) == 0) {
    return(data.frame(lookup_id = character(), uom = character()))
  }
  dbGetQuery(con, build_sql(ids))
}

# main function to read codelist, fetch uom, and save updated codelist with uom column
save_codelist <- function(output_path, input_path) {
  cl <- read_codelist(input_path)
  cl$lookup_id <- vmp_lookup_id(cl$term, cl$code)

  vmp_uom <- fetch_uom(
    cl$lookup_id[cl$dmd_type == "VMP"],
    build_vmp_uom_sql
  )
  amp_uom <- fetch_uom(
    cl$code[cl$dmd_type == "AMP"],
    build_amp_uom_sql
  )

  cl$uom <- NA_character_
  vmp_rows <- cl$dmd_type == "VMP"
  amp_rows <- cl$dmd_type == "AMP"
  cl$uom[vmp_rows] <- vmp_uom$uom[match(cl$lookup_id[vmp_rows], vmp_uom$lookup_id)]
  cl$uom[amp_rows] <- amp_uom$uom[match(cl$code[amp_rows], amp_uom$lookup_id)]

  out <- cl[, c("code", "term", "dmd_id", "dmd_type", "uom")]
  write_csv(out, output_path)
  invisible(out)
}

## save codelists with uom column

# statins
save_codelist(
  "local_codelists/user-emprestige-all-statins-uom.csv",
  "codelists/user-emprestige-all-statins-dmd.csv"
)
# codeine
save_codelist(
  "local_codelists/user-emprestige-codeine-for-pain-uom.csv",
  "codelists/user-emprestige-codeine-for-pain-dmd.csv"
)
# opioids
save_codelist(
  "local_codelists/opensafely-high-dose-long-acting-opioids-openprescribing-dmd-uom.csv",
  "codelists/opensafely-high-dose-long-acting-opioids-openprescribing-dmd.csv"
)
# injectables
save_codelist(
  "local_codelists/opensafely-long-acting-injectable-and-depot-antipsychotics-dmd-uom.csv",
  "codelists/opensafely-long-acting-injectable-and-depot-antipsychotics-dmd.csv"
)
# injectables - oxy
save_codelist(
  "local_codelists/opensafely-oxycodone-subcutaneous-dmd-uom.csv",
  "codelists/opensafely-oxycodone-subcutaneous-dmd.csv"
)
# inhalers
save_codelist(
  "local_codelists/user-emprestige-all-inhalers-dmd-uom.csv",
  "codelists/user-emprestige-all-inhalers-dmd.csv"
)

# uom tester
save_codelist(
  "local_codelists/user-chriswood-example-quantity-test-medications-uom.csv",
  "codelists/user-chriswood-example-quantity-test-medications.csv"
)
# acute meds 1
save_codelist(
  "local_codelists/user-chriswood-example-acute-medications-uom.csv",
  "codelists/user-chriswood-example-acute-medications.csv"
)
#acute meds 2
save_codelist(
  "local_codelists/user-chriswood-example-acute-medications-tramadol-uom.csv",
  "codelists/user-chriswood-example-acute-medications-tramadol.csv"
)
# repeat meds 1
save_codelist(
  "local_codelists/user-chriswood-example-repeat-medications-atorvastatin-uom.csv",
  "codelists/user-chriswood-example-repeat-medications-atorvastatin.csv"
)
# repeat meds 2
save_codelist(
  "local_codelists/user-chriswood-example-repeat-medications-ramipril-uom.csv",
  "codelists/user-chriswood-example-repeat-medications-ramipril.csv"
)
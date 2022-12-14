library(shiny)
library(DT)
library(RSQLite)
library(pool)
library(shinyjs)
library(uuid)
library(shinythemes)
library(bslib)
library(shinymanager)
library(dplyr)
library(shinyWidgets)
library(shinycssloaders)


credentials <- data.frame(
  user = c("labo", "admin"), # mandatory
  password = c("immuno", "adminsaad"), # mandatory
  stringsAsFactors = FALSE
)

set_labels(
  language = "en",
  "Please authenticate" = "Authentification",
  "Username:" = "Identifiant",
  "Password:" = "Mot de passe",
  "Login" = "Se connecter",
  "Username or password are incorrect" = "Identifiant ou mot de passe incorrect")


pool <- dbConnect(RMariaDB::MariaDB(), user='sql8516421', password='ThElKGv8BB', dbname='sql8516421', host='sql8.freesqldatabase.com')


#Create sql lite df
responses_dto <- data.frame(row_id = character(),
                            Machine = character(),
                            Reactif = character(),
                            Responsable = character(), 
                            BNE = character(),
                            BE = character(),
                            Statut= character(),
                            date = as.Date(character()),
                            stringsAsFactors = FALSE)

#Create responses table in sql database
dbWriteTable(pool, "responses_dto",responses_dto, overwrite = FALSE, append = TRUE)


#Label mandatory fields
labelMandatory <- function(label) {
  tagList(
    label,
    span("*", class = "mandatory_star")
  )
}

appCSS <- ".mandatory_star { color: red; }"




# ui
ui <- 
  fluidPage(
    tags$div(style = "position: absolute; top: -200px;",
             textOutput("clock")
    ),
    tags$head(
      tags$style(
        ".title {margin: auto; width: 700px}"
      )
    ),
    tags$div(class="title", titlePanel("Gestion du Stock du Laboratoire d'Immunologie")),
    tags$link(rel = "stylesheet", type = "text/css", href = "bootstrap.min"),
    theme = bs_theme(version = 4, bootswatch = "pulse"),
    shinyjs::useShinyjs(),
    shinyjs::inlineCSS(appCSS),
    fluidRow(
             sidebarPanel(width = "100%",
                          actionButton("add_button", "Ajouter", icon("plus")),
                          actionButton("edit_button", "Modifier", icon("edit")),
                          actionButton("copy_button", "Copier", icon("copy")),
                          actionButton("delete_button", "Effacer", icon("trash-alt"))),
             br(),
             fluidPage( width = "100%",
                        withSpinner(dataTableOutput("responses_table", width = "100%"))),
                       br()

    ))

ui <- secure_app(ui,
                 tags_top = tags$div(
                   
                   tags$img(
                     src = "ig.png", width = 50
                   )
                 ),
                 theme = bs_theme(version = 4, bootswatch = "pulse"),
                 status = "",
                   tags$div(
                     tags$img(
                       src = "ig.png", width = 100
                     )
                   ),
                   set_labels(
                     language = "en",
                     "Please authenticate" = "Authentification",
                     "Username:" = "Identifiant",
                     "Password:" = "Mot de passe",
                     "Login" = "Se connecter",
                     "Username or password are incorrect" = "Identifiant ou mot de passe incorrect")
)
                 
                 
                
# Server
server <- function(input, output, session) {
  
  
  res_auth <- secure_server(
    check_credentials = check_credentials(credentials)
  )
  
  output$auth_output <- renderPrint({
    reactiveValuesToList(res_auth)
  })
  
  #load responses_dto and make reactive to inputs  
  responses_dto <- reactive({
    
    #make reactive to
    input$submit
    input$submit_edit
    input$copy_button
    input$delete_button
    
    dbReadTable(pool, "responses_dto")
    
  })  
  
  #List of mandatory fields for submission
  fieldsMandatory <- c("Machine","Reactif","Responsable","BE","BNE","Statut")
  
  #define which input fields are mandatory 
  observe({
    
    mandatoryFilled <-
      vapply(fieldsMandatory,
             function(x) {
               !is.null(input[[x]]) && input[[x]] != ""
             },
             logical(1))
    mandatoryFilled <- all(mandatoryFilled)
    
    shinyjs::toggleState(id = "submit", condition = mandatoryFilled)
  })
  
  #Form for data entry
  entry_form <- function(button_id){
    
    showModal(
      modalDialog(
        div(id=("entry_form"),
            tags$head(tags$style(".modal-dialog{ width:400px}")),
            tags$head(tags$style(HTML(".shiny-split-layout > div {overflow: visible}"))),
            fluidPage(
              fluidRow(
                
                  cellWidths = c("250px", "100px"),
                  cellArgs = list(style = "vertical-align: top"),
                  textInput("Machine", labelMandatory("Machine"), placeholder = ""),
                  textInput("Reactif", labelMandatory("Reactif"), placeholder = ""),
                  textInput("Responsable", labelMandatory("Responsable"), placeholder = ""),
                  textInput("BE", labelMandatory("BE"), placeholder = ""),
                  textInput("BNE", labelMandatory("BNE"), placeholder = ""),
                  textInput("Statut", labelMandatory("Statut"), placeholder = ""),
                  
                helpText(labelMandatory(""), paste("champ obligatoire.")),
                actionButton(button_id, "Enregistrer")
              ),
              easyClose = TRUE
            )
        )
      )
    )
  }
  
  #
  fieldsAll <- c("Machine", "Reactif","Responsable","BE","BNE" ,"Statut")
  
  #save form data into data_frame format
  formData <- reactive({
    formData <- data.frame(row_id = UUIDgenerate(),
                           Machine = input$Machine,
                           Reactif = input$Reactif,
                           Responsable = input$Responsable, 
                           BE = input$BE,
                           BNE = input$ BNE,
                           Statut = input$Statut,
                           date = format(Sys.Date(), format="%d-%m-%Y"),
                           stringsAsFactors = FALSE)
    return(formData)
    
  })
  
  
  #Add data
  appendData <- function(data){
    quary <- sqlAppendTable(pool, "responses_dto", data, row.names = FALSE)
    dbExecute(pool, quary)
  }
  
  
  observeEvent(input$add_button, priority = 20,{
    
    entry_form("submit")
    
  })
  
 
  
  observeEvent(input$submit, priority = 20,{
    
    appendData(formData())
    shinyjs::reset("entry_form")
    removeModal()
    
  })
  
  observeEvent(input$submit, {
    showNotification("Ajouter avec succ??s", type = "message",duration = 2,closeButton=TRUE)
    Sys.sleep(1)
  })
 
  #delete data
  deleteData <- reactive({
    
    SQL_df <- RSQLite::dbReadTable(pool, "responses_dto")
    row_selection <- SQL_df[input$responses_table_rows_selected, "row_id"]
    
    quary <- lapply(row_selection, function(nr){
      RSQLite::dbExecute(pool, sprintf("DELETE FROM responses_dto WHERE (row_id = '%s')", nr))
      
    })
  })
  
  
  
  observeEvent(input$delete_button, priority = 20,{
    
    if(length(input$responses_table_rows_selected)>=1 ){
      deleteData()
    }
    
    showModal(
      
      if(length(input$responses_table_rows_selected) < 1 ){
        modalDialog(
          title = "Alert!",
          paste("Veuillez s??lectionner le(s) ligne(s)." ),easyClose = TRUE
        )
      })
  })
  
  
  #copy
  unique_id <- function(data){
    replicate(nrow(data), UUIDgenerate())
  }
  
  copyData <- reactive({
    
    SQL_df <- dbReadTable(pool, "responses_dto")
    row_selection <- SQL_df[input$responses_table_rows_selected, "row_id"] 
    SQL_df <- SQL_df %>% filter(row_id %in% row_selection)
    SQL_df$row_id <- unique_id(SQL_df)
    
    quary <- sqlAppendTable(pool, "responses_dto", SQL_df, row.names = FALSE)
    dbExecute(pool, quary)
    
  })
  
  observeEvent(input$copy_button, {
    showNotification("Copier avec succ??s", type = "error",duration = 2,closeButton=TRUE)
    Sys.sleep(1)
  })
  
  observeEvent(input$copy_button, priority = 20,{
    
    if(length(input$responses_table_rows_selected)>=1 ){
      copyData()
    }
    
    showModal(
      
      if(length(input$responses_table_rows_selected) < 1 ){
        modalDialog(
          title = "Warning",
          paste("Please select row(s)." ),easyClose = TRUE
        )
      })
    
  })
  
  #edit data
  observeEvent(input$edit_button, priority = 20,{
    
    SQL_df <- dbReadTable(pool, "responses_dto")
    
    showModal(
      if(length(input$responses_table_rows_selected) > 1 ){
        modalDialog(
          title = "Alert!",
          paste("Veuillez s??lectionner une seule ligne." ),easyClose = TRUE)
      } else if(length(input$responses_table_rows_selected) < 1){
        modalDialog(
          title = "Alert!",
          paste("Veuillez s??lectionner une ligne." ),easyClose = TRUE)
      })  
    
    if(length(input$responses_table_rows_selected) == 1 ){
      
      entry_form("submit_edit")
      
      updateTextInput(session, "Machine", value = SQL_df[input$responses_table_rows_selected, "Machine"])
      updateTextInput(session, "Reactif", value = SQL_df[input$responses_table_rows_selected, "Reactif"])
      updateTextInput(session, "Responsable", value = SQL_df[input$responses_table_rows_selected, "Responsable"])
      updateTextInput(session, "BE", value = SQL_df[input$responses_table_rows_selected, "BE"])
      updateTextInput(session, "BNE", value = SQL_df[input$responses_table_rows_selected, "BNE"])
      updateTextInput(session, "Statut", value = SQL_df[input$responses_table_rows_selected, "Statut"])
      
    }
    
  })
  
  observeEvent(input$submit_edit, priority = 20, {
    
    SQL_df <- dbReadTable(pool, "responses_dto")
    row_selection <- SQL_df[input$responses_table_row_last_clicked, "row_id"] 
    dbExecute(pool, sprintf('UPDATE responses_dto SET Machine = ?, Reactif = ?, Responsable = ?, BE = ? , 
                          BNE = ?, Statut = ? WHERE row_id = ("%s")', row_selection), 
              param = list(input$Machine,
                           input$Reactif,
                           input$Responsable,
                           input$BE,
                           input$BNE,
                           input$Statut))    
    
    removeModal()
    
  })
  
  observeEvent(input$submit_edit, {
    showNotification("Modifier avec succ??s", type = "default",duration = 2,closeButton=TRUE)
    Sys.sleep(1)
  })
  
  
  output$responses_table <- DT::renderDataTable({
    
    table <- responses_dto() %>% select(-row_id) 
    names(table) <- c("Machine", "Reactif", "Responsable","BE","BNE","Statut","date")
    table <- datatable(table, 
                       rownames = TRUE,
                       options = list(searching = TRUE, lengthChange = TRUE)
    )
    
  })
  
  output$responses_table <- DT::renderDataTable({
    
    responses_dto() %>% 
      datatable(extensions = 'Buttons',
                options = list(columnDefs = list(list(visible=FALSE, targets=c(1))),
                               dom = 'lfrtipB',
                buttons = c("pdf"),
                info = FALSE,
                paging = TRUE,
                language = list(search = 'Recherche')
                ))
              
  })
  
  
  
  output$downLoadFilter <- downloadHandler(
    filename = function() {
      past0('Filtered data-', Sys.Date(), '.csv', sep = '')
    },
    content = function(file){
      write.csv(responses_dto(),file)
    }
  )
  
  output$clock <- renderText({
    invalidateLater(5000)
    Sys.time()
  })
  
}
  

  


# Run the application 
shinyApp(ui = ui, server = server)





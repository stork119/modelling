### ###
### parallel computing ###
### ###

#### ####
#### ####
#### ####
# write.table(
#   x = data.frame(name = name,
#                  mse = results[["cmaes"]]$fmin, 
#                  maxit = maxit,
#                  stopfitness = stopfitness),
#   file = paste(output.path, paste("optimisation_", name, ".csv", sep = ""), sep = "/"),
#   sep = ",", 
#   row.names = FALSE, 
#   col.names = TRUE
# )
#### ####
run_parallel_computations <- function(path.list = list("id" = NULL,
                                                       "optimisation" = NULL,
                                                       "optimisation.data" = NULL),
                                      no_cores = 18,
                                      stopfitness = -10000000,
                                      #fun.optimisation = pureCMAES,
                                      #optimisation.res.par = "xmin"
                                      fun.optimisation = cma_es,
                                      optimisation.res.par = "par",
                                      data.model.list,
                                      fun_modify_input,
                                      optimisation_procedure = optimisation,
                                      par.list.ids.part = NULL,
                                      ...
                                      ){
  
  #TODO get path to logfile$path outside
  logfile <- list()
  logfile$name <- paste("optimisation", path.list$id, Sys.time(), sep = "-")
  logfile$path <- "scripts/"
  logfile$filename <- paste(logfile$path, logfile$name, ".log", sep = "")
  print(logfile$filename)
  InitLogging(filename = logfile$filename)
  remove(logfile)
  print(getwd())
  flog.info("run_parallel_computations", name ="logger.optimisation")
  print(12)
  
  ### initialization ###
  dir.create(path.list$optimisation.data, showWarnings = FALSE, recursive = TRUE)
  print(path.list$optimisation.data)
  optimisation.conditions.toload <- LoadOptimisationConditions(
    path.optimisation = path.list$optimisation,
    path.optimisation.data = path.list$optimisation.data,
    #maxit.tmp = maxit.tmp)
    ...)
  #rm(list = labels(optimisation.conditions.toload))
  #attach(optimisation.conditions.toload)
  
  variables <- optimisation.conditions.toload$variables
  variables.priming <- optimisation.conditions.toload$variables.priming
  optimisation.conditions <-  optimisation.conditions.toload$optimisation.conditions
  fun.optimisation.likelihood <- optimisation.conditions.toload$fun.optimisation.likelihood
  fun_run_model <- optimisation.conditions.toload$fun_run_model
  maxit <-  optimisation.conditions.toload$maxit 
  parameters.conditions <- optimisation.conditions.toload$parameters.conditions
  parameters.base <- optimisation.conditions.toload$parameters.base
  parameters.factor <- optimisation.conditions.toload$parameters.factor
  par.lower <-  optimisation.conditions.toload$par.lower
  par.upper <- optimisation.conditions.toload$par.upper
  par.optimised <- optimisation.conditions.toload$par.optimised
  stimulation.list <- optimisation.conditions.toload$stimulation.list
  data.exp.grouped <- optimisation.conditions.toload$data.exp.grouped
  data.exp.grouped.optimisation <- optimisation.conditions.toload$data.exp.grouped.optimisation
  data.exp.summarise.optimisation <- optimisation.conditions.toload$data.exp.summarise.optimisation
  lhs.res <- optimisation.conditions.toload$lhs.res
  par.list <- optimisation.conditions.toload$par.list
  par.list.ids <- optimisation.conditions.toload$par.list.ids
  ids <- optimisation.conditions.toload$ids
  
  
  if(!is.null(par.list.ids.part)){
    par.list.ids <- par.list.ids.part
  }
#### ####
    registerDoParallel(no_cores)
    test <- foreach(i = par.list.ids, .combine = list, .multicombine = TRUE ) %dopar%
    {
      tryCatch({
        #print(par.list.ids)
        par <- as.numeric(par.list[[i]])
        print(par)
        optimisation.res <- do.call(
          fun.optimisation,
          list(par = par, 
               # fun = optimisation,
               fn = optimisation_procedure,
               control = list(maxit = maxit,
                              stopfitness = stopfitness,
                              diag.sigma = TRUE,
                              diag.eigen = TRUE,
                              diag.pop = TRUE,
                              diag.value = TRUE),
               lower = par.lower[par.optimised],
               upper = par.upper[par.optimised],
               #stopeval = maxit,
               #stopfitness = stopfitness, 
               fun_run_model = fun_run_model,
               variables = variables,
               variables.priming = variables.priming,
               parameters.conditions = parameters.conditions,
               parameters.base = parameters.base,
               parameters.factor = parameters.factor,
               tmesh = tmesh,
               tmesh.list = tmesh.list,
               stimulation.list = stimulation.list,
               background = background,
               data.exp.grouped = data.exp.grouped.optimisation,
               data.exp.summarise = data.exp.summarise.optimisation,
               fun.likelihood = fun.optimisation.likelihood,
               par.optimised = par.optimised,
               fun_modify_input = fun_modify_input,
               #sigmapoints = sigmapoints))
               ...))
        
        path.optimisation.i <- paste(path.list$optimisation.data, i, sep = "/")
        dir.create(path.optimisation.i, recursive = TRUE, showWarnings = FALSE)
        
        par.exp.opt <- optimisation.res[[optimisation.res.par]]
        parameters <- parameters.factor
        parameters[par.optimised] <- parameters.factor[par.optimised]*(parameters.base[par.optimised])^par.exp.opt
        
        
        input <- fun_modify_input(parameters = parameters,
                                  variables = variables,
                                  variables.priming = variables.priming,
                                  parameters.conditions = parameters.conditions)
        
        parameters <- input$parameters
        variables  <- input$variables
        variables.priming <- input$variables.priming
        
        model.simulation <- do.call(fun_run_model,
                                    list(
                                      parameters = parameters,
                                      variables = variables,
                                      variables.priming = variables.priming,
                                      tmesh = tmesh,
                                      tmesh.list = tmesh.list,
                                      stimulation.list = stimulation.list,
                                      background = background,
                                      parameters.base = parameters.base,
                                      parameters.factor = parameters.factor,
                                      par.optimised = par.optimised,
                                      fun_modify_input = fun_modify_input,
                                      par = par.exp.opt,
                                      parameters.conditions = parameters.conditions,
                                      #sigmapoints = sigmapoints)),
                                      ...))
        error <- model.simulation$error
        # if(model.simulation$error){
        #   model.simulation <- do.call(run_model_mean,
        #                               list(parameters = parameters,
        #                                    variables = variables,
        #                                    variables.priming = variables.priming,
        #                                    tmesh = tmesh,
        #                                    tmesh.list = tmesh.list,
        #                                    stimulation.list = stimulation.list,
        #                                    background = background))
        #   
        # }
        result <- sapply(fun.likelihood.list, 
                         function(fun.likelihood){
                           sum( likelihood( 
                             fun.likelihood = fun.likelihood,
                             data.model = model.simulation$data.model,
                             data.exp.grouped = data.exp.grouped.optimisation,
                             data.exp.summarise = data.exp.summarise.optimisation))
                         })
        
        print(paste(c(path.optimisation.i, result, par.exp.opt), sep = " "))
        
        model.simulation$data.model$likelihood  <- 
          likelihood(data.model = model.simulation$data.model,
                     data.exp.grouped = data.exp.grouped.optimisation,
                     data.exp.summarise =  data.exp.summarise.optimisation,
                     fun.likelihood = fun.optimisation.likelihood)
        
        model.simulation$data.model$type <- "optimised"
        #print(sum(model.simulation$data.model$likelihood))
        gplot <- ggplot(model.simulation$data.model ,
                        mapping = aes(x = time,
                                      y = mean.lmvn,
                                      ymin = mean.lmvn - sqrt(sd.lmvn),
                                      ymax = mean.lmvn + sqrt(sd.lmvn),
                                      group = type,
                                      color = type)) +
          geom_point() +
          geom_line() +
          geom_errorbar() +
          facet_grid(priming ~ stimulation) + do.call(what = theme_jetka, args = plot.args) +
          geom_point(data = data.exp.summarise.optimisation %>% mutate(type = "data"), color = "black") +
          #geom_line(data = data.exp.summarise.optimisation %>% mutate(type = "data"), color = "black") +
          geom_errorbar(data = data.exp.summarise.optimisation %>% mutate(type = "data"),
                        color = "black") +
          ggtitle(paste(i, collapse = " "))
        
        ggsave(filename = paste(path.optimisation.i, "model_compare_variance.pdf", sep = "/"), 
               plot = gplot,
               width = plot.args$width,
               height =plot.args$height,
               useDingbats = plot.args$useDingbats)
        
        data <- do.call(rbind,append(data.model.list, list(optimised = model.simulation$data.model)))
        gplot <- list()
        gplot[[1]] <- ggplot(data = data,
                             mapping = aes(x = factor(time), y = likelihood, color = type)) +
          geom_point() + 
          do.call(theme_jetka, args = plot.args) + 
          facet_grid(priming ~ stimulation)
        
        gplot[[2]] <- ggplot(data = data %>% dplyr::filter(stimulation != 5),
                             mapping = aes(x = factor(time), y = likelihood, color = type)) +
          geom_point() + 
          do.call(theme_jetka, args = plot.args) + 
          facet_grid(priming ~ stimulation)
        ggsave(filename = paste(path.optimisation.i, "likelihood_comparison.pdf", sep = "/"), 
               plot = marrangeGrob(grobs = gplot, ncol = 1, nrow =1),
               width = plot.args$width,
               height =plot.args$height,
               useDingbats = plot.args$useDingbats)
        
        save_results(path.opt = path.optimisation.i,
                     data.model.opt = model.simulation$data.model,
                     par.opt = parameters,
                     par.exp.opt = par.exp.opt,
                     optimisation.opt = result,
                     optimisation.opt.colnames = names(fun.likelihood.list),
                     res.list = data.model.list,
                     data.exp.grouped = data.exp.grouped.optimisation,
                     error = error,
                     variables = variables,
                     variables.priming = variables.priming,
                     grid.ncol = ceiling(length(stimulation.list)/2))
        
        
        parameters.conditions.opt <- parameters.conditions
        parameters.conditions.opt$init <- 0
        parameters.conditions.opt$init[par.optimised] <- par
        parameters.conditions.opt$opt <- 0
        parameters.conditions.opt$opt[par.optimised] <- optimisation.res[[optimisation.res.par]]
        write.table(x = parameters.conditions.opt, 
                    file = paste(path.optimisation.i, "parameters_conditions.csv", sep = "/"),
                    sep = ",", 
                    row.names = FALSE, 
                    col.names = TRUE)
        
        
        
        # write.table(
        #   x = data.frame(mse = optimisation.res$fmin,
        #                  maxit = maxit,
        #                  stopfitness = stopfitness),
        #   file = paste(path.optimisation.i, paste("optimisation_steps", ".csv", sep = ""), sep = "/"),
        #   sep = ",",
        #   row.names = FALSE,
        #   col.names = TRUE
        # )
        saveRDS(object = optimisation.res, file = paste(path.optimisation.i, "optimisation.rds", sep = "/"))
        
        return(list(par = parameters))
      
      }, error =function(e){
        print(e)
        return(list(error = TRUE))
      })
    }
  stopImplicitCluster()
}


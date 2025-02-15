# Install/load libraries 
#If it's the first time running remember to go into the file InstallOrLoadLibraries
#and change "ind.install0<-FALSE" to "ind.install0<-TRUE" after the first time can be switch back to FALSE
source(file="InstallOrLoadLibraries.r")
#Import timeseries,it should be clean and processed already.
#Remember to check the first data entry of the timeseries,
#an usual error after applying a diff to a timeseries
#is that the first term is N/A
imported_ts = read.ts("log_diff_dump.csv", header = FALSE)
  
arimagarch <- function(current_timeseries){

  forecasts <- vector(mode="numeric", length=3)  # Create the forecasts vector to store the predictions
  ind <- vector(mode="numeric", length=100) #I don't remember why this is needed, but it doesn't work without it
  df0<-10 #fitdistr(x, "t") // Assuming a t dist for the residuals of ARIMA, 
  #                         // to compensate for fat tails on the dist, this can ba improved
  fixed.pars.df0=list(shape=df0) #The degress of freedom need to be stored like this
  
    
    # Fit the ARIMA model
    final.aic <- Inf   #this is where the final Akaike Information Criteria will be stored for the optimal (p,q)
    final.order <- c(0,0,0) #This is where the optimal (p,q) will be stored
    for (p in 0:10) for (q in 0:10) {   #try values between 0 and 10 for p and q
      if ( p == 0 && q == 0) {
        next
      }
      
      arimaFit = tryCatch( arima(current_timeseries, order=c(p, 0, q)),
                           error=function( err ) FALSE,
                           warning=function( err ) FALSE )  #running arima() with the current (p,q) with some error catching functions
      
      if( !is.logical( arimaFit ) ) {  #If arima model converge:
        current.aic <- AIC(arimaFit) #save the AIC of the current model
        if (current.aic < final.aic) {  #If the AIC of the current model is less than the one previously stored, update variables
          final.aic <- current.aic
          final.order <- c(p, 0, q)
          final.arima <- arima(current_timeseries, order=final.order)
        }
      } else {
        next
      }
    }
    
    # Specify and fit the GARCH(1,1) model, assuming t distribution 
    # with 10 degrees of freedom, the choice of degrees of freedom is arbitrary at this point
    # for a better fit try the model with several choices for the degrees of freedom and choose the
    # one that reduces the log-likelihood. For now I haven't done it.
    
    
    spec = ugarchspec(
      variance.model=list(garchOrder=c(1,1)),
      mean.model=list(armaOrder=c(final.order[1], final.order[3]), include.mean=T),
      distribution.model="std",
      fixed.pars=fixed.pars.df0
    ) #setting the specifications of the model in the variable spec, that's how rugarch library works
    fit = tryCatch(
      ugarchfit(
        spec, current_timeseries.0.Off.set, solver = 'hybrid'
      ), error=function(e) e, warning=function(w) w
    )  #running ugarchfit() with some error catching functions
    
 
    
    if(is(fit, "warning")) { #If GARCH(1,1) does not converge save in forecast vector
                             # the 1 step ARIMA forecast and the sd of the residuals

      forecast_arima = forecast(final.arima,1) #get 1 step forecast
      forecast_arima_mean = forecast_arima[["mean"]] #save the forecast
      sdfar=sd(final.arima[["residuals"]]) #save the standard deviation of the residuals
      forecasts[1] = paste(forecast_arima_mean[1], sdfar, "0", sep=",") #The "0" at the end is signaling 
                                                                        #the GARCH model didn't converge and ARIMA model is the only being used 
      
    } else { #else get garch forecast. and garch standard deviation
      fore = ugarchforecast(fit, n.ahead=1) #get 1 step forecast
      ind = fore@forecast$seriesFor #save the forecast
      cumsd = sd(fit@fit[["residuals"]]) #save the standard deviation of the residuals

      
      forecasts[1] = paste(ind, cumsd, "1", sep=",") #The 1 means that garch (1,1) model is being used
    }
  
    filename = "current_forecast.csv" #the name of the file that's where forecast vector will be outputed
    write.table(forecasts[1], file=filename, row.names=FALSE,  col.names=FALSE, quote=FALSE) #write forecast vector on the file named after filename
  return(1) 
}
arimagarch(imported_ts) #just running the function with the imported timeseries


#It should be checked if the series shows autocorrelation before running the function
#using an auto correlation test like the Ljung-Box test or ACF and PACF plots
#Something like:
#Box.test(imported_ts, lag = 1, type = c("Box-Pierce", "Ljung-Box"), fitdf = 0)


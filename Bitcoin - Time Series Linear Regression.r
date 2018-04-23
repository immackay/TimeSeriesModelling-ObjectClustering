require(jsonlite)
require(plotly)

##############################################
# get.polo.url()
#
#   Creates a poloniex api call url
#   Either for training (train=T) or testing (train=F)
#   Testing end is 90 days past training end
#
# @param start, default=1
#   The start of your training dataset
# @param end, default=1
#   The end of your training dataset
# @param pair, default="USDT_BTC"
#   Token pairs, taken from the market list on https://poloniex.com/
# @param period, default=86400
#   Period of dataset in seconds, default=1 day
# @param train, default=TRUE
#   Whether you want the training or testing url
# @returns string
#   API URL for accessing poloniex data
##############################################
get.polo.url <- function(start=1, end=1, pair="USDT_BTC", period=86400, train=TRUE) {
  # Returns OHLC + Volume
  POLO_URL <- "https://poloniex.com/public?command=returnChartData&currencyPair=%s&start=%d&end=%d&period=%i"
  # Returns tick by tick trades (max 50000)
  # POLO_URL2 <- "https://poloniex.com/public?command=returnTradeHistory&currencyPair=%s&start=%d&end=%d"

  START <- as.numeric(as.POSIXct(sprintf("2013-%d-01", start)), tz="GMT")
  END <- as.numeric(as.POSIXct(sprintf("2017-%d-01", end)), tz="GMT")
  PRED_START <- as.numeric(as.POSIXct(sprintf("2017-%d-01", end)), tz="GMT")
  PRED_END <- as.numeric(as.POSIXct(sprintf("2017-%d-01", end)), tz="GMT")+7776000
  # PERIOD_VALUES <- c(300, 7200, 86400)
  # 5min, 2hours, 24hours
  PREDICTION_LENGTH <- 90*86400/PERIOD # days
  if(train) {
    return(sprintf(POLO_URL, pair, START, END, period))
  }
  else {
    return(sprintf(POLO_URL, pair, PRED_START, PRED_END, period))
  }
}

# -------------------------------
# Data Creation and Visualization
# -------------------------------

df <- fromJSON(get.polo.url(start=1, end=1))
pred_df <- fromJSON(get.polo.url(start=1,end=1,train=F))
train <- ts(df[8])
test <- ts(pred_df[8])

# Plot the log of train and test, color test red
plot(log(c(train, test)), type="l", xlab="Time (Days)", ylab="Log of Volume Weighted Average Price", main="VWAP vs Time", sub="Black: Train\nRed: Test")
lines(x=seq(length(train)+1, length(train)+length(test)), y=log(test), col="red")

# -----------
# Differences
# -----------

# Plot difference of training set
plot(diff(train), ylab="Lagged Difference of VWAP", xlab="Time (Days)")
abline(h=0)

# Difference of log of training set
plot(diff(log(train)), ylab="Lagged Difference of VWAP", xlab="Time (Days)")
abline(a=0, b=0)

# --------------
# ACFs and PACFs
# --------------

acf(diff(log(train)), lag.max=50) # Rapid decay to zero - MA 1
pacf(diff(log(train)), lag.max=50) # Seasonal AR(35) - last line before 95% confidence

acf(diff(train), lag.max=50)
pacf(diff(train), lag.max=50)

# Create model, predict test set, and plot prediction with test set and error

ARIMA <- arima(train, order=c(1,1,0), seasonal=list(order=c(1,1,0), period=41))
ARIMA.pred <- predict(ARIMA, n.ahead=PREDICTION_LENGTH)
error <- abs((c(test)-ARIMA.pred$pred))
error <- ((error/max(error))*(min(log(test))/max(log(test))))+min(log(test))
#plot(log(c(train, test)), type="l", xlab="Time (Days)", ylab="Log of Volume Weighted Average Price")
#lines(x=seq(length(train)+1, length(train)+length(test)), y=log(test), col="red")
plot(log(test), lwd=2, xlab="Time (Days)", ylab="Log of VWAP")
lines(x=seq(along=test), log(ARIMA.pred$pred), col="blue", lwd=1)

#A1 <- arima(train, order=c(0,1,0), seasonal=list(order=c(1,0,0), period=35))
#A2 <- arima(train, order=c(0,1,1), seasonal=list(order=c(1,0,0), period=35))
#A3 <- arima(train, order=c(0,1,2), seasonal=list(order=c(1,0,0), period=35))
#A4 <- arima(train, order=c(1,1,0), seasonal=list(order=c(1,0,0), period=35))
#A5 <- arima(train, order=c(1,1,1), seasonal=list(order=c(1,0,0), period=35))
#sprintf("AIC: %f BIC: %f", AIC(A1), BIC(A1))
#sprintf("AIC: %f BIC: %f", AIC(A2), BIC(A2))
#sprintf("AIC: %f BIC: %f", AIC(A3), BIC(A3))
#sprintf("AIC: %f BIC: %f", AIC(A4), BIC(A4))
#sprintf("AIC: %f BIC: %f", AIC(A5), BIC(A5))

#B1 <- arima(train, order=c(0,1,1), seasonal=list(order=c(1,0,0), period=1))
#B2 <- arima(train, order=c(0,1,1), seasonal=list(order=c(1,0,0), period=7))
#B3 <- arima(train, order=c(0,1,1), seasonal=list(order=c(1,0,0), period=14))
#B4 <- arima(train, order=c(0,1,1), seasonal=list(order=c(1,0,0), period=21))
#B6 <- arima(train, order=c(0,1,1), seasonal=list(order=c(1,0,0), period=49))
#B7 <- arima(train, order=c(0,1,1), seasonal=list(order=c(1,0,0), period=90))
#sprintf("AIC: %f BIC: %f", AIC(B1), BIC(B1))
#sprintf("AIC: %f BIC: %f", AIC(B2), BIC(B2))
#sprintf("AIC: %f BIC: %f", AIC(B3), BIC(B3))
#sprintf("AIC: %f BIC: %f", AIC(B4), BIC(B4))
#sprintf("AIC: %f BIC: %f", AIC(B6), BIC(B6))
#sprintf("AIC: %f BIC: %f", AIC(B7), BIC(B7))

df2 <- fromJSON(get.polo.url())
series <- ts(df[8])
model <- arima(series, order=c(1,1,0), seasonal=list(order=c(1,1,0), period=41))
model.prediction <- predict(model, n.ahead=90)$pred
plot(log(ts(df2[8])), type='l')
lines(x=seq(length(series)+1, length(series)+length(model.prediction)), y=log(model.prediction), col="red")

# long
errors <- array(dim=c(4,20))
for(i in 1:4) {
  df <- fromJSON(get.polo.url(start=i,end=i))
  pred_df <- fromJSON(get.polo.url(start=i,end=i,train=F))
  train <- ts(df[8])
  test <- ts(pred_df[8])
  for(j in 19:38) {
    ARIMA <- arima(train, order=c(1,1,0), seasonal=list(order=c(1,1,1), period=j))
    ARIMA.pred <- predict(ARIMA, n.ahead=PREDICTION_LENGTH)
    error <- sum(abs(c(test)-ARIMA.pred$pred))
    errors[i,(j-21)] <- error
  }
}
for(i in 1:20) {
  print(mean(log(errors[,i])))
}

# install.packages('rnn')
library(rnn)
TRAIN_TIME = df[1]
TRAIN_VOLUME = df[6]
TRAIN_PRICE = df[4]
TEST_TIME = pred_df[1]
TEST_VOLUME = pred_df[6]
TEST_PRICE = pred_df[4]
library(ggplot2)
library(scales)
library(reshape)

cumbinom <- function (wins) {
	sapply(1:length(wins), function(n) {
    	binom.test(sum(wins[1:n]), n, 0.5, alternative='greater')$p.value
	})
}

cumulativeScoreAndPvalue <- function(h) {
	df <- with(h, data.frame(
		    trial         = seq_along(predictions),
		    informed      = predictionInformed,
		    computerScore = cumsum(predictions==choices), 
		    playerScore   = cumsum(predictions!=choices)
		))

	df <- melt(df, id.vars=c('trial', 'informed'))
	df <- cbind(df, type='score')

	# add the cumulative pvalues
	wins <- h$predictions == h$choices
	pHistory <- cumbinom(wins) 

	df <- rbind(df, data.frame(
		trial    = seq_along(pHistory),
		informed = h$predictionInformed, 
		variable = 'pvalue', 
		value    = pHistory, 
		type     = 'pvalue'
	))
	df
}

plotScores <- function(df) {
	ggplot(df, 
		aes(
			x     = trial, 
			y     = value
		)
	) + 
	facet_grid(type ~ ., scale = 'free') + 
	geom_step(aes(color = variable)) + 
	scale_color_hue(labels = c("Computer's score", "Your score", "P(better than random)")) +
	guides(color = guide_legend(title=NULL)) +
	xlab("Trial") +
	ylab(NULL) 
}


plotOverallScoreAndPvalue <- function(history) {
	# get the cumulative scores

	if (length(history$predictions) < 2) {
		return(NULL)
	}

	g <- plotScores(cumulativeScoreAndPvalue(history)) +
		geom_rect(
	    	aes(
				ymin  = -Inf, 
				ymax  = Inf, 
				xmin  = trial - 0.5, 
				xmax  = trial + 0.5, 
				alpha = informed & (variable == 'pvalue' | variable == 'playerScore')
			),
			color=alpha('black', 0)
		) + 
		scale_alpha_manual(values = c(0, 0.15), labels=c("Random", "From past behavior")) +
 		guides(alpha = guide_legend(title="Prediction")) + 
		ggtitle("Running score and p-value for one-sided\nbinomial test of P(computer guesses correctly) > 0.5")
}


plotInformedScoreAndPvalue <- function(history) {
	h <- list(
		predictions = history$predictions[history$predictionInformed],
		choices = history$choices[history$predictionInformed],
		predictionInformed = rep(T, sum(history$predictionInformed))
	)

	if (length(h$predictions) < 2) {
		return(NULL)
	}

	plotScores(cumulativeScoreAndPvalue(h)) + 
	ggtitle("Hypothetical running score and p-value for one-sided\nbinomial test of P(computer guesses correctly) > 0.5\n(considering only guesses informed by player behavior)")
}

plotPlaysBySituation <- function(history) {

	plays <- sapply(history$pastPlaysBySituation, function(v) {
		c(d = sum(v=='d'), s = sum(v=='s'))
	})

	df <- melt(plays)
	names(df) <- c('sd', 'situation', 'count')

	labeller <- function(var, value) {
	    value <- as.character(value)
	    if (var=='situation') { 
	        value[value=="ldl"] <- "lost\nplayed differently\nlost"
	        value[value=="ldw"] <- "lost\nplayed differently\nwon"
	        value[value=="lsl"] <- "lost\nplayed same\nlost"
	        value[value=="lsw"] <- "lost\nplayed same\nwon"
	        value[value=="wdl"] <- "won\nplayed differently\nlost"
	        value[value=="wdw"] <- "won\nplayed differently\nwon"
	        value[value=="wsl"] <- "won\nplayed same\nlost"
	        value[value=="wsw"] <- "won\nplayed same\nwon"
	    }
	    return(value)
	}

	ggplot(df, aes(
			x=sd, 
			y=count, 
			fill=sd)
	) + 
	geom_bar(stat="identity", show_guide=F) + 
	facet_grid(. ~ situation, labeller = labeller) +
	scale_x_discrete(labels = c("different", "same")) +
	theme(axis.text.x = element_text(angle=45)) +
	ylab("Count") +	
	xlab("Following move") +
	ggtitle("Your moves, classified by immediately-preceding game situation")
}

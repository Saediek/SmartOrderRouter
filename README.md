Abstract
==SmartOrderRouter or SOR is a bleeding edge technology which routes a trade to the best executable conditions of a trade at a time (t).
==In the defi world today there exist many decentralised trading platforms or exchanges which allows traders to trade tokens of their choices.
==Also this decentralised Exchanges having different pricing mechanisms like the infamous CPAMM,CSAMM,CLAMM and so on
==To cut the story short this exchanges have different pricing mechanisms which leads to discrepancies in price,which are commonly exploited by MEV's.
==SOR helps scan the defi market on a particular chain and execute a trade based on the best condition offered for that trade, which would allow traders to exploit price discrepancies in the market.
==SOR introduces an incentive for itself.A trade is considered as a bet that the router wouldn't find a better price than minAmountOut,if the router doesn't
==find a better price the transaction revert's else the router gets to keep a share of the difference between the trade output and minimum expected amount which is capped at 10%
This way the router is incentivised to beat the minimum expected amount and users are incentivised to pick a accurate  prices.. 

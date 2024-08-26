@defcomp revenue_recycle begin

    country          = Index()

    Y                           = Parameter(index=[time, country])         		# Output net of damages and abatement costs (million USD2017 per year)
    country_carbon_tax       	= Parameter(index=[time, country])         		# Carbon tax ($/tCO2).
    LOCAL_DAMFRAC_KW            = Parameter(index=[time, country])              # Country-level damages as a share of net GDP based on country-level temperatures.
    E_gtco2                 	= Parameter(index=[time, country])      		# Industrial carbon emissions (GtCo2 yr⁻¹).
    l           				= Parameter(index=[time, country])  			# Country population (thousands)
    lost_revenue_share      	= Parameter()                           		# Share of carbon tax revenue that is lost and cannot be recycled (1 = 100% of revenue lost)
    global_recycle_share    	= Parameter(index=[country])            		# Shares of country revenues that are recycled globally as international transfers (1 = 100%)
    switch_recycle              = Parameter()                                   # Switch, recycling of tax revenues
    switch_scope_recycle	   	= Parameter() 									# Switch, carbon tax revenues recycled at country (0) or  global (1) level
    switch_global_pc_recycle    = Parameter()                                   # Switch, carbon tax revenues recycled globally equal per capital (1)

    tax_revenue 				= Variable(index=[time, country]) 				# Country carbon tax revenue ($1000)
    tax_pc_revenue              = Variable(index=[time, country]) 				# Carbon tax revenue per capita ($1000s/person)
    total_tax_revenue           = Variable(index=[time]) 		         		# Total carbon tax revenue ($1000), sum of tax revenue in all countries
    global_revenue 				= Variable(index=[time]) 						# Carbon tax revenue from globally recycled country revenues ($1000)
    country_pc_dividend 	    = Variable(index=[time, country]) 				# Total per capita carbon tax dividends, including any international transfers ($1000s/person).
    country_pc_dividend_domestic_transfers = Variable(index=[time, country]) 	# Per capita carbon tax dividends from domestic redistribution ($1000s/person).
    country_pc_dividend_global_transfers = Variable(index=[time, country]) 		# Per capita carbon tax dividends from international transfers ($1000s/person).


    function run_timestep(p, v, d, t)

        #######################################
        ## Compute country carbon tax revenues 
        #######################################

       for c in d.country

            # Calculate carbon tax revenue for each country ($1000).
            # Note, emissions in GtCO2 and tax in 2017 $ per tCO2
            # Convert to tCo2 (Gt to t: *1e9) and to thousand dollars ($ to $1000: /1e3) -> *1e6
            v.tax_revenue[t,c] = (p.E_gtco2[t,c] * p.country_carbon_tax[t,c] * 1e6) * (1.0 - p.lost_revenue_share)

            # Carbon tax revenue per capita for each country ($1000 per capita)
            # population l in thousands, so divide by 1e3
            v.tax_pc_revenue[t,c] =  v.tax_revenue[t,c] / p.l[t,c] / 1e3

        end # country loop

        ##########################################################################
        ## Compute total tax revenue available and revenue recycled at global level 
        ##########################################################################

        # total of all countries carbon tax revenue ($1000).
        v.total_tax_revenue[t] = sum(v.tax_revenue[t,:])

        # Calculate tax revenue from globally recycled revenue ($1000)
        
        if p.switch_scope_recycle==1 && p.switch_scope_recycle==1 && !is_first(t) # if revenues recycled, and if recycled at global level
            
            v.global_revenue[t] = sum(v.tax_revenue[t,:] .* p.global_recycle_share[:])

        else  # no revenues recycled at global level, or first period

            v.global_revenue[t] = 0 

        end

        # Compute endogenous global level revenue recycling share
        # if total_tax_revenue != 0, then the share is global_revenue/total_tax_revenue, else the share is set to 0
        temp_global_recycle_share_endogeneous = (v.total_tax_revenue[t]!=0 ? v.global_revenue[t]/v.total_tax_revenue[t] : 0.0) 

       ###########################################################
       ## Distribute total tax revenue to countries as per capita
       ## dividends, according to recycling scenario
       ###########################################################

        #Calculate total recycled per capita dividend for each country, from domestic and globally recycled revenue.
        # In 1000$ per capita: revenues already in 1000$ and population l in thousands, so for 1000$ per capita, divide by 1e3

        for c in d.country

            if p.switch_recycle==1 # revenue reycling is on

                if p.switch_scope_recycle==0 #Revenues recycled only at the country level on per capita basis

                    v.country_pc_dividend_domestic_transfers[t,c] = v.tax_revenue[t,c] / p.l[t,c] / 1e3
                    v.country_pc_dividend_global_transfers[t,c] = 0

                elseif p.switch_scope_recycle==1  #Revenues recycled at the global (and at country level depending on global revenue share)
                    
                    # revenues recycled globally with an exogenous share
                    # Recycle a share (1-global_recycle_share) of global revenue within country (in $1000 per capita)
                    v.country_pc_dividend_domestic_transfers[t,c] = (1-p.global_recycle_share[c]) * v.tax_revenue[t,c]  / p.l[t,c] / 1e3

                    # Distribute globally recycled revenues to countries according to scenario
                    ## Globally recycled revenues recycled on a per capita basis =======================
                    if p.switch_global_pc_recycle==1
                        v.country_pc_dividend_global_transfers[t,c] = v.global_revenue[t] / (sum(p.l[t,:])*1e3)
                    end # test for recycling type in the case of global recycling

                end # test for scope of recycling (global/local)

            elseif p.switch_recycle==0 # revenue recycling is off
                v.country_pc_dividend_domestic_transfers[t,c] = 0
                v.country_pc_dividend_global_transfers[t,c] = 0

            end # test if revenue reycling on or off

            # Sum per capita dividends from domestic and global redistribution
            v.country_pc_dividend[t,c] = v.country_pc_dividend_domestic_transfers[t,c] + v.country_pc_dividend_global_transfers[t,c]

        end # country loop
    end # timestep
end

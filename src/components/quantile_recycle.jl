@defcomp quantile_recycle begin

    country          = Index()
    regionwpp       = Index()
	quantile		 = Index()

    ABATEFRAC               	= Parameter(index=[time, country])      		# Cost of CO2 emission reductions as share of gross economic output.
    LOCAL_DAMFRAC_KW            = Parameter(index=[time, country])              # Country-level damages as a share of net GDP based on country-level temperatures.
    CPC                     	= Parameter(index=[time, country])      		# Country level consumption per capita
	l           				= Parameter(index=[time, country])  			# Country population (thousands)
	mapcrwpp   				    = Parameter(index=[country])        			# Map from country index to wpp region index
	Y           				= Parameter(index=[time, country]) 				# Output net of damages and abatement costs (million USD2017 per year)
    country_pc_dividend 	    = Parameter(index=[time, country]) 				# Total per capita carbon tax revenue, including any international transfers ($1000s/person).
    tax_pc_revenue              = Parameter(index=[time, country])              # Carbon tax revenue per capita from country emissions  ($1000s/person)
    switch_recycle              = Parameter()                                   # Switch recycling of tax revenues
    nb_quantile                	= Parameter(default=10)							# Number of quantiles
	min_study_gdp               = Parameter()                          			# Minimum observed per capita GDP value found in elasticity studies ($/person).
    max_study_gdp            	= Parameter()                          			# Maximum observed per capita GDP value found in elasticity studies ($/person).
    elasticity_intercept     	= Parameter()                          			# Intercept term to estimate time-varying income elasticity.
    elasticity_slope         	= Parameter()                          			# Slope term to estimate time-varying income elasticity.
    damage_elasticity        	= Parameter()                          			# Income elasticity of climate damages (1 = proportional to income)
	quantile_consumption_shares = Parameter(index=[time, country, quantile]) 	# Income shares of deciles
    recycle_share           	= Parameter(index=[country, quantile]) 		# Share of carbon tax revenue recycled back to each quantile.

    CO2_income_elasticity    	= Variable(index=[time, country])             	# Elasticity of CO2 price exposure with respect to income.
    abatement_cost_dist		 	= Variable(index=[time, country, quantile]) 	# Quantile distribution shares of mitigation costs
    carbon_tax_dist		     	= Variable(index=[time, country, quantile]) 	# Quantile distribution shares of CO2 tax burden
    damage_dist					= Variable(index=[time, country, quantile]) 	# Quantile distribution shares of climate damages

    pc_gdp                   	= Variable(index=[time, country])      			# Per capita output net of abatement and damages (2017 USD / person).
	qc_base                  	= Variable(index=[time, country, quantile])  	# Pre-damage, pre-abatement cost, pre-tax quantile consumption (thousands 2017 USD yr⁻¹).
    qc_post_damage_abatement 	= Variable(index=[time, country, quantile])  	# Post-damage, post-abatement cost per capita quantile consumption (thousands 2017 USD/person yr⁻¹).
    qc_post_tax              	= Variable(index=[time, country, quantile])  	# Quantile per capita consumption after subtracting out carbon tax (thousands 2017 USD/person yr⁻¹).
    qc_post_recycle          	= Variable(index=[time, country, quantile])  	# Quantile per capita consumption after recycling tax back to quantiles (thousands 2017 USD/person yr⁻¹).
    qc_share				 	= Variable(index=[time, country, quantile])  	# Quantile (share) per capita consumption (%)
	total_c_post_recycle  	 	= Variable(index=[time, country]) 				# Total consumption per country after recycling
    CPC_post                    = Variable(index=[time, country])               # Country consumption per capita post recycle
    CPC_post_rwpp               = Variable(index=[time, regionwpp])              # Region consumption per capita post recycle
    CPC_post_global             = Variable(index=[time])                        # Global consumption per capita post recycle

	gini_cons          		 	= Variable(index=[time, country])				# Country consumption gini (%)
    gini_cons_rwpp              = Variable(index=[time, regionwpp])              # Region consumption gini (%)
    gini_cons_global            = Variable(index=[time])                        # Global consumption gini (%)
	mu_cons				        = Variable(index=[time, country])				# Parameter mu of the lognormal distribution of consumption
	sigma_cons			        = Variable(index=[time, country])				# Parameter sigma of the lognormal distribution of consumption


    function run_timestep(p, v, d, t)

        # temporary variable for global population in t 
        temp_pop_global = sum(p.l[t,:])

        #temporary variable for quantile population in t (country x quantile)
        temp_pop_quantile = repeat( (p.l[t,:] / p.nb_quantile), 1, p.nb_quantile) # all quantiles within a country have same pop, by definition

        for c in d.country

            # Calculate net per capita income ($/person).
            # Note, Y in $million (1e6) and population in thousands (1e3), so scale by 1e3
            v.pc_gdp[t,c] = p.Y[t,c] / p.l[t,c] * 1e3

            ########################################################################################################
            ## Calculate time-varying income elasticity of CO2 price exposure (requires pc_gdp units in $/person).
            # Note, hold elasticity constant at boundary value if GDP falls outside the study support range.

            if v.pc_gdp[t,c] < p.min_study_gdp
               # GDP below observed study values.
               v.CO2_income_elasticity[t,c] = p.elasticity_intercept + p.elasticity_slope * log(p.min_study_gdp)
           elseif v.pc_gdp[t,c] > p.max_study_gdp
               # GDP above observed study values.
               v.CO2_income_elasticity[t,c] = p.elasticity_intercept + p.elasticity_slope * log(p.max_study_gdp)
           else
               #GDP within observed study values.
               v.CO2_income_elasticity[t,c] = p.elasticity_intercept + p.elasticity_slope * log(v.pc_gdp[t,c])
           end

            #################################################
            ## Compute consumption distributions for quantiles
            #################################################

            # Calculate quantile distribution shares of CO2 tax burden and mitigation costs (assume both distributions are equal) and climate damages.
			v.abatement_cost_dist[t,c,:] = country_quantile_distribution(v.CO2_income_elasticity[t,c], p.quantile_consumption_shares[t,c,:], p.nb_quantile)
			v.carbon_tax_dist[t,c,:]     = country_quantile_distribution(v.CO2_income_elasticity[t,c], p.quantile_consumption_shares[t,c,:], p.nb_quantile)
			v.damage_dist[t,c,:]         = country_quantile_distribution(p.damage_elasticity, p.quantile_consumption_shares[t,c,:], p.nb_quantile)

			# Create a temporary variable used to calculate NICE baseline quantile consumption (just for convenience).
			temp_C = p.nb_quantile * p.CPC[t,c] * (1.0 + p.LOCAL_DAMFRAC_KW[t,c]) / (1.0 - p.ABATEFRAC[t,c])
			for q in d.quantile

				# Calculate pre-damage, pre-abatement cost quantile consumption.
				v.qc_base[t,c,q] = temp_C * p.quantile_consumption_shares[t,c,q]

				# Calculate post-damage, post-abatement cost per capita quantile consumption (bounded below to ensure consumptions don't collapse to zero or go negative).
				# Note, this differs from standard NICE equation because quantile CO2 abatement cost and climate damage shares can now vary over time.
				v.qc_post_damage_abatement[t,c,q] = max(v.qc_base[t,c,q] - (p.nb_quantile* p.CPC[t,c] * p.LOCAL_DAMFRAC_KW[t,c] * v.damage_dist[t,c,q]) - (temp_C * p.ABATEFRAC[t,c] * v.abatement_cost_dist[t,c,q]), 1e-8)

				# Subtract tax revenue from each quantile based on quantile CO2 tax burden distributions.
				# Note, per capita tax revenue and consumption should both be in $1000/person.
				v.qc_post_tax[t,c,q] =  v.qc_post_damage_abatement[t,c,q] - (p.nb_quantile * p.tax_pc_revenue[t,c] * v.carbon_tax_dist[t,c,q])

				# Recycle tax revenue by adding shares back to all quantiles
				if p.switch_recycle==0 # In the NO revenue recycling case (distributionally neutral), refund tax revenues equal to the initial burden

					v.qc_post_recycle[t,c,q] = v.qc_post_tax[t,c,q] + (p.nb_quantile * p.tax_pc_revenue[t,c] * v.carbon_tax_dist[t,c,q])

				elseif p.switch_recycle==1 # In the revenue recycling case, distribute divididends from country and/or global tax revenue (assume recycling shares constant over time)

					v.qc_post_recycle[t,c,q] = v.qc_post_tax[t,c,q] + (p.nb_quantile * p.country_pc_dividend[t,c] * p.recycle_share[c,q])
				end

			end # quantile

			#calculate total consumption (to calculate consumption shares at later stage)
			v.total_c_post_recycle[t,c] = sum(v.qc_post_recycle[t,c,:])

            v.CPC_post[t,c] = v.total_c_post_recycle[t,c] / p.nb_quantile

            v.qc_share[t,c,:] .= v.qc_post_recycle[t,c,:]./ v.total_c_post_recycle[t,c]*100

            #################
            ## Compute Gini 
            ################

			#gini consumption
            v.gini_cons[t,c] =  gini(convert(Vector{Real}, v.qc_share[t,c,:])) *100

            if v.gini_cons[t,c]  > 0 && v.gini_cons[t,c] <100
                v.sigma_cons[t,c] = sqrt(2)*quantile(Normal(0,1), (v.gini_cons[t,c]/100 + 1)/2)
    			v.mu_cons[t,c] =  log(p.CPC[t,c]*1e3) - ((v.sigma_cons[t,c])^2)/2 #CPC is in thousands USD per year
            else
                v.gini_cons[t,c] = missing
            end
        end # country loop

        for rwpp in d.regionwpp
            country_indices = findall(x->x==rwpp , p.mapcrwpp) #Country indices for the region

            v.CPC_post_rwpp[t,rwpp] = sum(p.l[t,country_indices] .* v.CPC_post[t, country_indices]) / sum(p.l[t,country_indices])
            v.gini_cons_rwpp[t,rwpp] = gini(convert(Vector{Real},vec(v.qc_post_recycle[t,country_indices,:])), convert(Vector{Real},vec(temp_pop_quantile[country_indices,:])))*100

        end # region loop

        v.CPC_post_global[t] = sum(v.total_c_post_recycle[t,:] .* p.l[t,:] ./ p.nb_quantile) / temp_pop_global

        v.gini_cons_global[t] = gini(convert(Vector{Real},vec(v.qc_post_recycle[t,:,:])), convert(Vector{Real},vec(temp_pop_quantile))) *100

    end # timestep
end

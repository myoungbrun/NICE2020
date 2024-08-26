@defcomp welfare begin

    country         = Index()
    regionwpp       = Index()
	quantile        = Index()


    qc_post_recycle         = Parameter(index=[time, country, quantile])  	# Quantile per capita consumption after recycling tax back to quantiles (thousands 2017 USD/person yr⁻¹).
    η                       = Parameter()                                   # Inequality aversion
    nb_quantile             = Parameter()
    l                       = Parameter(index=[time, country])              # Population (thousands)
    mapcrwpp                = Parameter(index=[country])                    # Map from country index to wpp region index

    cons_EDE_country        = Variable(index=[time, country])               # Equally distributed welfare equivalent consumption (thousands 2017 USD/person yr⁻¹)
    cons_EDE_rwpp            = Variable(index=[time, regionwpp])
    cons_EDE_global         = Variable(index=[time])               # Equally distributed welfare equivalent consumption (thousands 2017 USD/person yr⁻¹)
    welfare_country         = Variable(index=[time, country])
    welfare_rwpp           = Variable(index=[time, regionwpp])
    welfare_global          = Variable(index=[time])

    function run_timestep(p, v, d, t)

        if !(p.η==1)
            for c in d.country
            v.cons_EDE_country[t,c] = (1/p.nb_quantile * sum(p.qc_post_recycle[t,c,:].^(1-p.η) ) ) ^(1/(1-p.η))
            v.welfare_country[t,c] = (p.l[t,c]/p.nb_quantile) * sum(p.qc_post_recycle[t,c,:].^(1-p.η) ./(1-p.η))

            end # country loop

            for rwpp in d.regionwpp
                country_indices = findall(x->x==rwpp , p.mapcrwpp) #Country indices for the region

                v.cons_EDE_rwpp[t,rwpp] =  ( sum(p.l[t,country_indices] .*  v.cons_EDE_country[t,country_indices].^(1-p.η) ) / sum(p.l[t,country_indices]) )^(1/(1-p.η))
                v.welfare_rwpp[t,rwpp] = sum( v.welfare_country[t,country_indices]  )

            end # region loop

            v.cons_EDE_global[t] = ( sum(p.l[t,:]  .*  v.cons_EDE_country[t,:].^(1-p.η) ) / sum(p.l[t,:]) )^(1/(1-p.η))
            v.welfare_global[t] = sum( v.welfare_country[t,:]  )

        elseif p.η==1

            for c in d.country
            v.cons_EDE_country[t,c] = exp(1/p.nb_quantile * sum( log.(p.qc_post_recycle[t,c,:]) ))
            v.welfare_country[t,c] = p.l[t,c]/p.nb_quantile * sum(log.(p.qc_post_recycle[t,c,:]))

            end # country loop

            for rwpp in d.regionwpp
                country_indices = findall(x->x==rwpp , p.mapcrwpp) #Country indices for the region

                v.cons_EDE_rwpp[t,rwpp] = exp( sum(p.l[t,country_indices]  .*  log.(v.cons_EDE_country[t,country_indices]) )  / sum(p.l[t,country_indices]) )
                v.welfare_rwpp[t,rwpp] = sum( v.welfare_country[t,country_indices]  )

            end # region loop

            v.cons_EDE_global[t] = exp( sum(p.l[t,:]  .*  log.(v.cons_EDE_country[t,:]) )  / sum(p.l[t,:]) )
            v.welfare_global[t] = sum( v.welfare_country[t,:]  )
        end


    end # timestep
end

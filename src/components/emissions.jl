# -----------------------------------------------------------
# Emissions
# -----------------------------------------------------------

@defcomp emissions begin
    country         = Index()       # The regions index must be specified for each component
    regionwpp       = Index()       # Index for WPP regions

    σ          = Parameter(index=[time, country])  # Emissions output ratio, GtCO2 per million 2017 US$
    YGROSS     = Parameter(index=[time, country])  # Gross output (million 2017 US$ per year)
    μ          = Parameter(index=[time, country]) 	# Emission control rate GHGs
    mapcrwpp  = Parameter(index=[country])        # Map from country index to WPP region index

    E_gtco2            = Variable(index=[time, country])   # Country level total greenhouse gas emissions (GtCO2 yr⁻¹)
    E_Global_gtco2     = Variable(index=[time])            # Global emissions (sum of all country emissions) (GtCO2 yr⁻¹)
    E_Global_gtc       = Variable(index=[time])            # Global emissions in units of gigatonnes of carbon (GtC yr⁻¹).
    E_gtco2_rwpp      = Variable(index=[time, regionwpp]) # Regional emissions of WPP regions (GtCO2 yr⁻¹)

    function run_timestep(p, v, d, t)
        # Define an equation for E
        for c in d.country

            v.E_gtco2[t,c] = p.YGROSS[t,c] * p.σ[t,c] * (1-p.μ[t,c])
        end

        # Define an equation for E_Global.
        v.E_Global_gtco2[t] = sum(v.E_gtco2[t,:])

        # Convert emissions to GtC units (required by FAIR).
        v.E_Global_gtc[t] = v.E_Global_gtco2[t] * 12.01/44.01

        # Regional emissions for WPP regions
        for rwpp in d.regionwpp
            country_indices = findall(x->x==rwpp , p.mapcrwpp) #Country indices for the region
            v.E_gtco2_rwpp[t,rwpp]= sum(v.E_gtco2[t, country_indices])
        end

    end

end

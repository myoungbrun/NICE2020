using Query, JSON, DataFrames, CSVFiles

nice_inputs = JSON.parsefile("data/nice_inputs.json") # This file contains the economic and emissions calibration and the list of used country codes
# the json file reads in a several nested dictionaries, where in each case the "last" dictionary contains the keys, "units", "dimensions", "notes", and "x". The "x" key always contains the data to be read into a DataFrame.

countries = nice_inputs["country_set_ssp_183"]["x"]["countrycode"] # country set (ISO3 codes in alphabetic order)countries = string.(countries)

# REMOVE SOMALIA, VENEZUELA, NEW CALEDONIA, and TRINIDAD AND TOBAGO
filter!( x-> !(x in ["SOM", "VEN", "NCL", "TTO" ]), countries )

sort!(countries) # Sort country names to be in alphabetical order.

#-----------------------------------------------------------------
# Load mapping of countries to World Population Prospects regions
#----------------------------------------------------------------

mapping_wpp_regions = DataFrame(load("data/WPP_regions_country_list.csv"))

# Filter countries in the country set and sort
filter!(:countrycode => in(countries), mapping_wpp_regions )
sort!(mapping_wpp_regions, :countrycode)

# Extract region index as vector
map_country_region_wpp = mapping_wpp_regions[:, :WPP_region_number]

# Extract vector of regions names in order of region numbers
names_regions_df = unique(mapping_wpp_regions[:, [:WPP_region_name,:WPP_region_number] ])
sort!(names_regions_df, :WPP_region_number)
wpp_regions = names_regions_df[:, :WPP_region_name]


#-----------------------------------------
# Load economic and emissions calibration
#----------------------------------------

## Population

pop_raw = DataFrame(nice_inputs["economy"]["pop_projected"]["x"])
filter!(:countrycode => in(countries), pop_raw ) #Filter countries in list

# Unstack the dataframe to have year x country dimensions.
pop_unstack = unstack(pop_raw, :year, :countrycode, :pop_projected, allowduplicates=true)

# Sort the columns (country names) into alphabetical order.
pop = select(pop_unstack, countries)

## Initial capital

init_capital_raw = DataFrame(nice_inputs["economy"]["k0"]["x"])
filter!(:countrycode => in(countries), init_capital_raw)

# Sort the country rows into alphabetical order
initial_capital = sort(init_capital_raw, :countrycode)

# Extract vector of initial capital
k0 = initial_capital[:, :k0]


## Total factor productivity

productivity_raw = DataFrame(nice_inputs["economy"]["tfp"]["x"])
filter!(:countrycode => in(countries), productivity_raw)

# Unstack the dataframe to have year x country dimensions.
productivity_unstack = unstack(productivity_raw, :year, :countrycode, :tfp, allowduplicates=true)

# Sort the columns (country names) into alphabetical order.
productivity = select(productivity_unstack, countries)

## Savings rate

srate_raw = DataFrame(nice_inputs["economy"]["srate"]["x"])
filter!(:countrycode => in(countries), srate_raw)

# Unstack the dataframe to have year x country dimensions.
srate_unstack = unstack(srate_raw, :year, :countrycode, :srate, allowduplicates=true)

# Sort the columns (country names) into alphabetical order.
srate = select(srate_unstack, countries)

## Depreciation

depreciation_raw = DataFrame(nice_inputs["economy"]["depreciation"]["x"])
filter!(:countrycode => in(countries), depreciation_raw)

# Unstack the dataframe to have year x country dimensions.
depreciation_unstack = unstack(depreciation_raw, :year, :countrycode, :depreciation, allowduplicates=true)

# Sort the columns (country names) into alphabetical order.
depreciation = select(depreciation_unstack, countries)

## Emissions intensity

emissionsrate_raw = DataFrame(nice_inputs["emissions"]["bauProjectionV1"]["x"])
filter!(:countrycode => in(countries), emissionsrate_raw)

# Unstack the dataframe to have year x country dimensions.
emissionsrate_unstack = unstack(emissionsrate_raw, :year, :countrycode, :intensity, allowduplicates=true)

# Sort the columns (country names) into alphabetical order.
emissionsrate = select(emissionsrate_unstack, countries)

#----------------------------------------
# Load inequality calibration
#----------------------------------------

## Income distribution for 2020
deciles = ["d1", "d2", "d3", "d4", "d5", "d6", "d7", "d8", "d9", "d10"]
consumption_deciles_2020_raw = DataFrame(load("data/consumption_deciles_2020.csv",header_exists=true))
#consumption_deciles_2020_raw = DataFrame(nice_inputs["income_quantile_2020"]["x"])
filter!(:countrycode => in(countries), consumption_deciles_2020_raw)

consumption_distribution = Matrix(select!(consumption_deciles_2020_raw, deciles))

# Consumption distribution varying with time
consumption_deciles_2020_2100_raw = DataFrame(load("data/consumption_deciles_2020_2100.csv",  header_exists=false))
consumption_deciles_2020_2100_countries = filter(:Column1 => x -> x in countries, consumption_deciles_2020_2100_raw )
consumption_deciles_2020_2100_mat = Matrix(consumption_deciles_2020_2100_countries[:,2:end])

consumption_distribution_2020_2300=zeros(Float64, length(2020:2300), length(countries), 10)

for c in 1:length(countries)
    for t in 0:1:80
        for d in 1:10
            consumption_distribution_2020_2300[t+1,c,d] = consumption_deciles_2020_2100_mat[c, t*10 + d ]
        end
    end
    for t in 81:280
        for d in 1:10
            consumption_distribution_2020_2300[t+1,c,d] = consumption_distribution_2020_2300[81, c, d] # repeat last value
        end
    end
end

#--------------------------------------
# Load parameters for revenue recycling
#--------------------------------------

# Results from the  meta-regression based on study results to calculate elasticity vs. ln gdp per capita relationship.
meta_intercept = 3.22
meta_slope =  -0.22
meta_min_study_gdp = 647
meta_max_study_gdp = 48892

#--------------------------------
# Load abatement cost parameters
#-------------------------------

## Global Backstop price from DICE 2023, in 2017USD per tCO2
initial_pback = 670
pback_decrease_rate_2020_2050 = 0.01
pback_decrease_rate_after_2050 = 0.001

pbacktime_2020_2050 = [initial_pback * (1-pback_decrease_rate_2020_2050)^(t-2020) for t in 2020:1:2050 ]
pbacktime_after_2050 = [ pbacktime_2020_2050[end] * (1-pback_decrease_rate_after_2050)^(t-2050) for t in 2051:1:2300 ]

full_pbacktime = [pbacktime_2020_2050; pbacktime_after_2050 ]

#----------------------------------------------
# Load country-level damage function parameters
#----------------------------------------------

## Extract parameters for the country level damage functions based on Kalkuhl and Wenz

country_damage_coeffs = DataFrame(load("data/country_damage_coefficients.csv",header_exists=true))
filter!(:countrycode => in(countries), country_damage_coeffs ) #Filter countries in list
sort!(country_damage_coeffs, :countrycode)

beta1_KW = country_damage_coeffs[!, :beta1_KW]
beta2_KW = country_damage_coeffs[!, :beta2_KW]


#----------------------------------------
# Load FAIR initial conditions for 2020
#----------------------------------------

# This loads FAIR output for the year 2020 saved from a default run started in 1750 (making it possible to initialize FAIR in 2020).
init_aerosol     = DataFrame(load(joinpath(@__DIR__, "fair_initialize_2020", "aerosol.csv")))
init_ch4         = DataFrame(load(joinpath(@__DIR__, "fair_initialize_2020", "ch4.csv")))
init_co2         = DataFrame(load(joinpath(@__DIR__, "fair_initialize_2020", "co2.csv")))
init_flourinated = DataFrame(load(joinpath(@__DIR__, "fair_initialize_2020", "flourinated.csv")))
init_montreal    = DataFrame(load(joinpath(@__DIR__, "fair_initialize_2020", "montreal.csv")))
init_n2o         = DataFrame(load(joinpath(@__DIR__, "fair_initialize_2020", "n2o.csv")))
init_temperature = DataFrame(load(joinpath(@__DIR__, "fair_initialize_2020", "temperature.csv")))
init_tj          = DataFrame(load(joinpath(@__DIR__, "fair_initialize_2020", "tj.csv")))


#-------------------------------------------------------
# Load country-level temperature pattern scaling values
#-------------------------------------------------------

# For now, just use a single CMIP6 model.
cmip6_model = "CESM2"

# Set the SSP scenario.
ssp_scenario = "ssp2"

# Select pattern type (options = "patterns.area", "patterns.gdp.2000", "patterns.pop.2000", "patterns.gdp.2100", "patterns.pop.2100")
pattern_type = Symbol("patterns.pop.2100")

# Load raw pattern file and extract relevant model+scenario coefficients for each country.
raw_patterns = load(joinpath(@__DIR__, "cmip6_patterns_by_country.csv")) |>
               @filter(_.source == cmip6_model && _.scenario == ssp_scenario) |>
               @orderby(_.iso3) |>
               @filter(_.iso3 in countries) |> DataFrame

# Select pattern type from varios options.
cmip_pattern = raw_patterns[!, pattern_type]

#-------------------------------------------------------
# Load-country level environment starting values
#-------------------------------------------------------

Env0_data = DataFrame(load("data/e0.csv",  header_exists=true))
filter!(:countrycode => in(countries), Env0_data)
Env0 = Env0_data[:, :e0]

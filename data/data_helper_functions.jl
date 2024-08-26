# #-------------------------------------------------------------------------------------------------------
# #-------------------------------------------------------------------------------------------------------
# # This file contains functions that are used for various data loading and cleaning processes.
# #-------------------------------------------------------------------------------------------------------
# #-------------------------------------------------------------------------------------------------------

# Load helper function packages
using CSVFiles
using DataFrames
using MimiFAIRv2


#######################################################################################################################
# GET FAIR INITIAL CONDITIONS
#######################################################################################################################
# Description: This function runs the FAIR climate model for a user-specified year and saves the model state conditions.
#              This will allow a user to initilize FAIR in a specific year (default year = 1750).
#
# Function Arguments:
#
#       year = User-defined year to save the FAIR model output for (i.e. in what future year will you initilize FAIR).
#----------------------------------------------------------------------------------------------------------------------

function fair_init_conditions(year::Int)

	# Get index for user-specified year.
	year_index = findfirst(x -> x == year, 1750:2500)

	# Load and run a version of FAIR.
	m = MimiFAIRv2.get_model(emissions_forcing_scenario="ssp245")
	run(m)

	#------------------------------------------
	# Extract Model Results for Specific Year
	#------------------------------------------

	# Temperature change for three thermal pools.
	tj = DataFrame(Tj=m[:temperature, :Tj][year_index, :])

	# Global temperature anomaly.
	temperature = DataFrame(Temperature=m[:temperature, :T][year_index, :])

	# Aerosol+ gases.
	aerosol = DataFrame(hcat(m[:aerosol_plus_cycles, :GU_aerosol_plus][year_index, :],
						 	 m[:aerosol_plus_cycles, :R_aerosol_plus][year_index, :, :],
						 	 m[:aerosol_plus_cycles, :aerosol_plus_conc][year_index, :]),
						  	 [:GU,:R1,:R2,:R3,:R4,:concentration])

	# Montreal gases.
	montreal = DataFrame(hcat(m[:montreal_cycles, :GU_montreal][year_index, :],
						  	  m[:montreal_cycles, :R_montreal][year_index, :, :],
						  	  m[:montreal_cycles, :montreal_conc][year_index, :]),
						   	  [:GU,:R1,:R2,:R3,:R4,:concentration])

	# Flourinated gases.
	flourinated = DataFrame(hcat(m[:flourinated_cycles, :GU_flourinated][year_index, :],
						    	 m[:flourinated_cycles, :R_flourinated][year_index, :, :],
							     m[:flourinated_cycles, :flourinated_conc][year_index, :]),
				                 [:GU,:R1,:R2,:R3,:R4,:concentration])

	# Nitrous oxide.
	n2o = DataFrame(vcat(m[:n2o_cycle, :GU_n2o][year_index, :],
					     m[:n2o_cycle, :R_n2o][year_index, :],
						 m[:n2o_cycle, :n2o][year_index, :])',
						  [:GU,:R1,:R2,:R3,:R4,:concentration])

	# Methane.
	ch4 = DataFrame(vcat(m[:ch4_cycle, :GU_ch4][year_index, :],
						 m[:ch4_cycle, :R_ch4][year_index, :],
						 m[:ch4_cycle, :ch4][year_index, :])',
						  [:GU,:R1,:R2,:R3,:R4,:concentration])

	# Carbon Dioxide.
	co2 = DataFrame(vcat(m[:co2_cycle, :GU_co2][year_index, :],
					 	 m[:co2_cycle, :R_co2][year_index, :],
					 	 m[:co2_cycle, :co2][year_index, :])',
					  	 [:GU,:R1,:R2,:R3,:R4,:concentration])

	#------------------------------------------
	# Save results.
	#------------------------------------------

	# Make a folder in the NICE v2.0 "data" folder to store FAIR initial conditions.
	fair_path = joinpath("data", "fair_initialize_"*string(year))
	mkdir(fair_path)

	# Save initial condition results for temperature and individual gases.
	save(joinpath(fair_path, "tj.csv"), tj)
	save(joinpath(fair_path, "temperature.csv"), temperature)
	save(joinpath(fair_path, "aerosol.csv"), aerosol)
	save(joinpath(fair_path, "montreal.csv"), montreal)
	save(joinpath(fair_path, "flourinated.csv"), flourinated)
	save(joinpath(fair_path, "n2o.csv"), n2o)
	save(joinpath(fair_path, "ch4.csv"), ch4)
	save(joinpath(fair_path, "co2.csv"), co2)
end

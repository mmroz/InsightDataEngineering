# FEC data parsing class
# Mark Mroz


# These dependencies are required for the use of the method .blank? as defined in active_support
	# See more at https://guides.rubyonrails.org/active_support_core_extensions

require 'active_support'
require 'active_support/core_ext'

class DonationaAnalytics

	# Static Variables
		# The positions of the data after removing the pipe
		# See  https://classic.fec.gov/finance/disclosure/metadata/DataDictionaryContributionsbyIndividuals.shtml

	CMTE_ID_POSITION          =       0
	NAME_POSITION             =       7
	ZIP_CODE_POSITION         =       10
	TRANSACTION_DT_POSITION   =       13
	TRANSACTION_AMT_POSITION  =       14
	OTHER_ID_POSITION         =       15

	def parse_analytics_file(stat_data_file, percentile_file, output_file )
		
		# File handling
		percentile_value = File.open(percentile_file).read.to_f
		File.open(output_file, 'w') {|file| file.truncate(0) }

		# Hashes for data processing
		user_cmt_hash 		  = 	  {}
		count_hash 			  = 	  {}
		sum_hash 			  = 	  {}
		cmt_cont_hash 		  = 	  {}


		File.open(stat_data_file).each do |row|  				 #take each line

			row 		= 	row.split('|')

			cmt 		= 	row[CMTE_ID_POSITION]
			name 		= 	row[NAME_POSITION]
			zip 		= 	row[ZIP_CODE_POSITION][0,5]
			date 		= 	row[TRANSACTION_DT_POSITION][-4,4]
			amount 		= 	(row[TRANSACTION_AMT_POSITION]).to_i
 
			next if !row[OTHER_ID_POSITION].empty? || (zip.blank? || zip == "00000")  || cmt.blank? || date.blank? || amount < 0

			# Create a unique hash of the zip and name

			user_row = { zip: zip , name: name }


			if !user_cmt_hash[:"#{user_row}"].nil?					#repeat donor

				if count_hash[:"#{cmt}"].nil? 						#never had a donation to this cmt
					count_hash[:"#{cmt}"] = 0
					sum_hash[:"#{cmt}"] = {:"#{date}" => amount} 
					cmt_cont_hash[:"#{cmt}"] = {:"#{date}" => [amount]}
				else 												#add the cmt to the hashes
					count = count_hash[:"#{cmt}"] += 1

					if sum_hash[:"#{cmt}"][:"#{date}"].nil? 		#there is a repeat contribution for a new calendar year
						sum = sum_hash[:"#{cmt}"][:"#{date}"] = amount
					else 											#there is a contribution for an existing calendar year
						sum = sum_hash[:"#{cmt}"][:"#{date}"] += amount
					end

					if cmt_cont_hash[:"#{cmt}"][:"#{date}"].nil?	 #there is a repeat contribution for a new calendar year
						cmt_cont_hash[:"#{cmt}"][:"#{date}"] = [amount]
					else 											 #there is a contribution for an existing calendar year
						cmt_cont_hash[:"#{cmt}"][:"#{date}"] << amount
					end

					sorted_array = (cmt_cont_hash[:"#{cmt}"][:"#{cmt_cont_hash[:"#{cmt}"].max[0]}"] << amount).sort 
					percentile = sorted_array[((percentile_value / 100.0) * sorted_array.count.to_f).round]

					open(output_file, 'a') do |f|
					  f << "#{cmt}|#{zip}|#{date}|#{percentile}|#{sum}|#{count}" << "\n"
					end

				end 												 #end cmt processing

			else 													 #first time donor

				user_cmt_hash[:"#{user_row}"] = cmt
				count_hash[:"#{cmt}"] = 0
				sum_hash[:"#{cmt}"] = {:"#{date}" => amount} 
				cmt_cont_hash[:"#{cmt}"] = {:"#{date}" => [amount]}


			end 													 #end repeat donor

		end 														 #end each line 

		puts "Finished execution"

	end 															 #end parse_analytics_file method

end 																 #end DonationaAnalytics class






# MAIN

analytics = DonationaAnalytics.new
analytics.parse_analytics_file ARGV[0], ARGV[1], ARGV[2]

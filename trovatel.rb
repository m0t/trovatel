#!/usr/bin/ruby

#	trovatel.rb
#	a m0t's Studios Production
#
#	BUGS: cognomi composti
#
#   GOAL: recuperare numeri o nomi da www.infobel.com/it/italy/
#
#	REQUISITI:
#	ruby (scritto con ruby 1.8)
#	rubygems
#	optionparser
#	net/http
#	uri
#	activesupport
#	term-ansicolor

require 'rubygems'
require 'commandline/optionparser'
require 'net/http'
require 'uri'
require 'active_support'
require 'term/ansicolor'

include Term::ANSIColor
include CommandLine

module Trovatel

	#args: body of the page
	#returns: number of records found
	def Trovatel.extractRecCount(body)
		#<strong><span id="lblRecordCount">70</span>
		no_match = /Non ci sono risultati per la vostra ricerca/
		return "0" if body =~ no_match
		rec_count = %r{lblRecordCount">(\d+)</span>}
		rec_count =~ body
		return $1
	end

	#args: body of the page
	#returns: array of raw records
	def Trovatel.extract_records(body)
		rec_matcher = /<div class="result-box">(?:.+class="result-box-foot">)+?/
		return body.scan(rec_matcher)
	end

	def Trovatel.get_page(base_url,pars,pos)
		url=base_url+"?"+pos+"&"+pars
		
		begin
			uri = URI.parse(url)
			#req = NET::HTTP::Post.new(uri.path)
			#req.set_form_data({'qlastname'=>last, 'qfirstname'=>first,'qcity'=>'', 'qSelLang2'=>'', 'Submit'=>'Ricerca', 'inphCoordType'=>'EPSG'}, ';')
			#res = Net::HTTP.post_form(uri, {'qlastname'=>last, 'qfirstname'=>first,'qcity'=>'', 'qSelLang2'=>'', 'Submit'=>'Ricerca', 'inphCoordType'=>'EPSG'} )
			res = Net::HTTP.get_response(uri)
		rescue Errno::ECONNREFUSED
			puts "Connection refused"
			exit
		end
		return res if res.is_a?Net::HTTPOK
		puts res.class,url
		return nil
	end

	#returns all raw records found
	def Trovatel.parse_page(base_url, pars)
		posSetter="FirstRec="
		resPerPage=5

		cnt=0
		res=get_page(base_url, pars, posSetter+cnt.to_s)

		#XXX control results
		tot_cnt=extractRecCount(res.body)
		puts "received "+tot_cnt+" results"
		
		return nil if tot_cnt.to_i < 1

		records = []
		records += extract_records(res.body)
		cnt+=resPerPage
		while cnt < tot_cnt.to_i
			res = get_page(base_url, pars, posSetter+cnt.to_s)
			records += extract_records(res.body) if res
			cnt += resPerPage
		end

		return records
	end

	#args: a record (= string containing raw data)
	#returns: hash with the strings we want
	def Trovatel.process_record(record)
		#puts "record!\n"
		results = []
		#one result for regexp, otherwise warning (also, strange things can and do happen)
		tel = /Telefono:<\/td><td>(\d+)/
		#name = /QName=([A-Z]+(?:\W[A-Z]+)*)/
		#different approach
		name = /QName=([^a-z]+)&/
		#street = /QStreet=([A-Z]+(?:\.? [A-Z]+)*)/
		street = /QStreet=([^a-z]+)&/
		num = /QNum=((?:\d+(?:\/?\d+|\w+)?)|(?:[^a-z]+))&/
		zip = /QZip=(\d+)/
		city = /QCity=([A-Z]+(?:\.? [A-Z]+)*)/
		rexp = [name, street, num, tel, zip, city]
		rexp.each do |x| 
			#tmp = record.mb_chars.scan(x) 
			tmp = record.scan(x) 
			if tmp.size != 1
				#puts "results error in regexp "+rexp.index(x).to_s
				results << nil
			else
				#puts tmp[0]
				results << tmp[0].to_s
			end		
		end
		#some postprocessing
		#results[0].mb_chars.gsub!(/\W+/m, ' ')
		results[0].gsub!(/\W+/m, ' ')
		
		resHash={'name' =>results[0], 'street'=>results[1], 'num'=>results[2], 'tel'=>results[3], 'zip'=>results[4], 'city'=>results[5] }

		return resHash
	end

	#result is an array of strings
	def Trovatel.print_record(result)
		puts "Name:\t\t"+red(result['name']) 
		#puts "Address:\t"+green(result['street']+" "+result['num']+" "+result['city']+" "+result['zip']) #if result['street'] and result['num'] and result['city'] and result[zip]
		print "Address:\t"
		print green(result['street']) if result['street']
		print " "+green(result['num']) if result['num']
		print " - "+green(result['city']) if result['city']
		print " "+green(result['zip']) if result['zip']
		print "\n"
		puts "Phone:\t\t"+cyan(result['tel']) #if result['tel'] 
	end

end

people_url='http://www.infobel.com/it/italy/People.aspx'
phone_url='http://www.infobel.com/it/italy/Inverse.aspx' #?qPhone=0445510303

def message_and_exit(msg)
	if msg
		puts msg
	else
		puts %q{usage: turn off pc, light a joint and be happy}
	end
	exit
end

#http://rubyforge.org/docman/view.php/632/170/index.html
opts =[ Option.new(:names => "-t",
				   :arg_arity => [1,1],
				   :opt_found => OptionParser::GET_ARGS,
				   :opt_not_found => false,
				   :opt_description => "search phone number, exclude -n and -N"
				   #:opt_not_found => OptionParser::OPT_NOT_FOUND_BUT_REQUIRED
				   ),
		Option.new(:names => "-n",
			       :arg_arity => [1,-1],
				   :opt_found => OptionParser::GET_ARGS,
				   :opt_not_found => false,
				   :opt_description => "set lastname. exclude -N"
				  ),
		Option.new(:names => "-N",
			       :arg_arity => [1,-1],
				   :opt_found => OptionParser::GET_ARGS,
				   :opt_not_found => false,
				   :opt_description => "set complete name, format: <last> <first>"
				  ),
		Option.new(:names => "-c",
				   :arg_arity => [1,-1],
				   :opt_found => OptionParser::GET_ARGS,
				   :opt_not_found => false,
				   :opt_description => "set city"),
		Option.new(:flag, :names => %w[-h --help], 
				   :opt_description => "print this help"		  
				  )]


op = OptionParser.new(opts)
od = op.parse
optsize=od.hash.size

usage=op.to_s
message_and_exit(usage) if od['-h']

telMode=false
first="";last="";city=""
#spaces are url-encoded here
if not od['-t']
	message_and_exit(usage) unless od['-n'] or od['-N']
	if od['-n']
		last=od['-n'].join("%20") if od['-n'].instance_of?Array
		last=od['-n'] if od['-n'].instance_of?String
	else
		message_and_exit(usage) if od['-N'].size < 2
		last=od['-N'][0..-2].join("%20")
		first=od['-N'][-1]
	end
else
	telMode=true
	phone=od['-t']
end 

if od['-c']
	city=od['-c'].join("%20")if od['-c'].instance_of?Array
	city=od['-c'] if od['-c'].instance_of?String
end

#parameters are now set , determine type of search
if telMode
	base_url=phone_url
	pars="qPhone="+phone
else
	base_url=people_url
	pars="qlastname="+last+"&qfirstname="+first+"&qcity="+city
	#XXX:always check param are in the right variables!
	#also, here we should do some input sanitization, nothing fancy,
	#but something should be done. Now space are url-encoded above.
	#pars = pars.gsub(" ", "%20")
	#print pars
end

#start the rock'n'rolla
records=Trovatel.parse_page(base_url,pars)

exit unless records

results = []
records.each {|r| results << Trovatel.process_record(r) }

id=1
print "\n"
results.each do |r|
	puts id
	Trovatel.print_record(r)
	puts "\n"
	id+=1
end


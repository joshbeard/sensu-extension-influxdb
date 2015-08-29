#
# Sensu extension for writing to InfluxDB
#
# Supports writing via EventMachine, which can potentially offer better
# performance or via the influxdb Rubygem.
#
# This is a bit dirty right now.
#
# Author: Josh Beard <josh@signalboxes.net>
#
require 'influxdb'
require 'json'
require 'em-http-request'
require 'eventmachine'

#
# Sensu To Influxdb
#
module Sensu::Extension
  class SensuToInfluxDB < Handler
    def name
      'influxdb'
    end

    def definition
      {
        type: 'extension',
        name: 'influxdb'
      }
    end

    def description
      'Outputs metrics to InfluxDB'
    end

    def post_init(); end

    def stop
      yield
    end

    def run(event_data)
      opts = @settings['influxdb'].each_with_object({}) do |(k, v), sym|
        sym[k.to_sym] = v
      end

      ## What method do we want to use to write
      ## 'em' for EventMachine and 'influx' for influxdb gem
      method = opts[:method].nil? ? 'em' : opts[:method]

      event = JSON.parse(event_data)

      client_name = event['client']['name']
      metric_name = event['check']['name']
      ip          = event['client']['address']
      metric_raw  = event['check']['output']

      data = []
      metric_raw.split("\n").each do |metric|
        m = metric.split
        next unless m.count == 3
        key,value,time = metric.split(/\s+/)
        #value = value.match('\.').nil? ? Integer(value) : Float(value) rescue value.to_s
        value = value.to_f

        if opts[:strip_metric]
          key.gsub!(/^.*#{opts[:strip_metric]}\.(.*$)/, '\1')
        end

        if opts[:strip_host]
          key.gsub!(/^.*#{client_name}\.(.*$)/, '\1')
        end

        point = {
          series: key,
          tags: {
          host: client_name,
          metric: metric_name,
          ip: ip
        },
          values: { value: value },
          timestamp: time
        }

        data.push(point)

        ## Build the write for whatever method we're using
        if method == 'em'
          uri   = 'http://' + opts[:server] + ':' + opts[:port] + '/write?db=' + opts[:database] + '&u=' + opts[:username] + '&p=' + opts[:password] + '&precision=s'
          query = "#{key},host=#{client_name},metric=#{metric_name},ip=#{ip} value=#{value} #{time.to_s}"
          post_em(uri,query)
        else
          influx_opts = {
            database: opts[:database],
            host:     opts[:server],
            username: opts[:username],
            password: opts[:password],
            port:     opts[:port],
            use_ssl:  opts[:use_ssl]
          }
          post_influx(influx_opts,data)
        end

        unless opts[:debug_log].nil?
          msg = "#{Time.now} #{Time.at(time.to_i)} | key: #{key} #{client_name} #{value}\n"
          File.open(opts[:debug_log], 'a') { |f| f.write(msg) }
        end
      end

      yield("InfluxDB: Handler Extension Finished", 0)
    end

    #
    # Method to use EventMachine to write the data
    #
    def post_em(uri,query)
      begin
        http = EventMachine::HttpRequest.new(uri).post(
          :head => { "content-type" => "application/x-www-form-urlencoded" },
          :body => query
        )
        em_err = http.errback {
          @logger.error '[InfluxDB]: HTTP error'
        }
        em_cb  = http.callback {
          http.response_header.status
          http.response_header
          http.response
        }
      rescue => e
        @logger.error "[InfluxDB]: Failed to write point to InfluxDB: #{em_cb} // #{em_err} // #{e} "
      end
    end

    #
    # Method to use the influxdb gem to write the data
    #
    def post_influx(opts,data)
      begin
        influxdb_data = InfluxDB::Client.new opts[:database],
          host:     opts[:server],
          username: opts[:username],
          password: opts[:password],
          port:     opts[:port],
          use_ssl:  opts[:use_ssl]

        influxdb_data.write_points(data)
      rescue => e
        @logger.error "[InfluxDB]: Failed to write point to InfluxDB: #{e} "
      end
    end

  end
end

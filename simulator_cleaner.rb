#!/usr/bin/env ruby

require 'json'
require 'tty-prompt'

class SimulatorCLI

  def initialize
    navigate_to_device_directory
    get_device_data
    # puts JSON.pretty_generate(@devices)

    get_target_devices
    
    puts "\nDeleting device data:"
    delete_device_data

    
    if recreate_devices? 
      puts "Recreating following devices:"
      recreate_devices
    end

    puts "Device data cleared. \nNew devices state:\n"
    get_device_data
    list_devices
  end

  def navigate_to_device_directory
    Dir.chdir(File.expand_path('~/Library/Developer/CoreSimulator/Devices/'))
  end

  def get_device_data
    command_result = `xcrun simctl list devices --json`
    devices_json = JSON.parse(command_result)["devices"]
    # puts JSON.pretty_generate(devices_json)
    @devices = devices_json.flat_map do |runtime, device_list| 
      device_list.map do |device, device_index|
      {
        "name" => device["name"],
        "state" => device["state"],
        "udid" => device["udid"],
        "device_type" => device["deviceTypeIdentifier"], # the model
        "runtime" => runtime, # the iOS version
      }
      end
    end
  end

  def parse_runtime(device_index)
    return @devices[device_index]["runtime"].split(".").last
  end

  def get_target_devices 
    choices = @devices.map.with_index do |device, index|
      size = get_device_image_size(device["udid"])
      runtime = parse_runtime(index)
      
      # You may wish to include the device state in this prompt 
      { name: "#{device["name"]} [#{runtime}] -- #{size}", value: index }
    end

    # indexes correspond with @devices array
    @victims = TTY::Prompt.new.multi_select("Select devices to clean:", choices) 
    @victims.empty? ? exit : @victims
  end

  def recreate_devices?
    TTY::Prompt.new.yes?("Would you like to recreate the device?\nThis will restore the device in to its default state.\n")
  end

  def recreate_devices
    # You must be in the directory where the devices are stored
    # Use `navigate_to_device_directory` to navigate to the correct directory
    @victims.each do |index|
      puts "  #{@devices[index]["name"]} [#{parse_runtime(index)}]..."
      `xcrun simctl create "#{@devices[index]["name"]}" "#{@devices[index]["device_type"]}" "#{@devices[index]["runtime"]}"`
    end
  end

  def delete_device_data
    @victims.each_with_index do |index|
      puts "  #{@devices[index]["name"]} [#{parse_runtime(index)}]..."
      `xcrun simctl delete "#{@devices[index]["udid"]}"`
    end
  end

  def get_device_image_size(udid)
    if Dir.exist?(udid)
      return `du -sh #{udid} | cut -f1`.strip
    else 
      return "Directory not found"
    end
  end

  def list_devices
    @devices.each_with_index do |device, index|
      size = get_device_image_size(device["udid"])
      runtime = parse_runtime(index)
      puts "  #{device["name"]} [#{runtime}] -- #{size}"
    end
  end

end


SimulatorCLI.new
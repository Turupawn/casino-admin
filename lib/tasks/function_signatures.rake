namespace :function_signatures do
  desc "Populate function signatures from contract ABIs"
  task populate: :environment do
    puts "Populating function signatures from contract ABIs..."
    signatures = AbiSignatureService.populate_all_contract_signatures
    puts "Successfully populated #{signatures.length} function signatures"
    
    # Show some examples
    puts "\nSample signatures:"
    FunctionSignature.first(5).each do |fs|
      puts "  #{fs.name}: #{fs.signature_str} -> #{fs.signature_hex} (#{fs.contract_name})"
    end
  end

  desc "Auto-populate function signatures (called after migrations)"
  task auto_populate: :environment do
    # Only populate if table exists and is empty
    if ActiveRecord::Base.connection.table_exists?('function_signatures') && FunctionSignature.count == 0
      puts "Creating unknown function signature..."
      FunctionSignature.find_or_create_by(name: 'unknown') do |fs|
        fs.signature_str = 'unknown()'
        fs.signature_hex = '0x00000000'
        fs.contract_name = 'unknown'
      end
      puts "Auto-populating function signatures..."
      AbiSignatureService.populate_all_contract_signatures
      puts "Function signatures auto-populated successfully"
    end
  end

  desc "Clear all function signatures"
  task clear: :environment do
    count = FunctionSignature.count
    FunctionSignature.delete_all
    puts "Cleared #{count} function signatures"
  end

  desc "Show function signatures for a specific contract"
  task :show, [:contract_name] => :environment do |t, args|
    contract_name = args[:contract_name]
    if contract_name
      signatures = FunctionSignature.for_contract(contract_name)
      puts "Function signatures for #{contract_name}:"
      signatures.each do |fs|
        puts "  #{fs.name}: #{fs.signature_str} -> #{fs.signature_hex}"
      end
    else
      puts "Usage: rails function_signatures:show[contract_name]"
    end
  end
end

# Hook into db:migrate to auto-populate function signatures
Rake::Task['db:migrate'].enhance do
  Rake::Task['function_signatures:auto_populate'].invoke
end
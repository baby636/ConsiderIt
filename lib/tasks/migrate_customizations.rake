task :migrate_customizations => :environment do 

  # # migrate branding
  Subdomain.where("branding is not NULL").each do |s|
    branding = JSON.load(s.branding)
    customizations = JSON.load(s.customizations || "{}")

    customizations['banner'] ||= {}
    banner = customizations['banner']

    changed = false 

    branding.each do |k,v|

      if k == 'primary_color' && v != '#eee' && v != ""
        banner['background_css'] = v
        changed = true
      elsif k == 'masthead_header_text' && v != ""
        banner['title'] = v
        changed = true
      end
    end

    if changed 
      s.customizations = JSON.dump(customizations)
      pp "Imported branding #{s.name}: ", banner #JSON.dump(customizations)
      s.save 
    end

  end

  pp '\n************\n'

  Subdomain.all.each do |s|
    changed = false
    if s.customizations 
      customizations = JSON.load(s.customizations || "{}")

      if customizations.has_key?('background')
        customizations['banner'] ||= {}
        customizations['banner']['background_css'] = customizations['background']
        customizations.delete('background')

        changed = true
      end

      if customizations.has_key?('prompt')
        customizations['banner'] ||= {}
        customizations['banner']['title'] = customizations['prompt']
        customizations.delete('prompt')
        changed = true
      end

      if changed 
        pp "Migrated customizations for #{s.name}: ", customizations['banner'] #JSON.dump(customizations)
        s.customizations = JSON.dump(customizations)
        s.save 
      end

    end
  end

end
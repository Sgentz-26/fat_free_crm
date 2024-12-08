# frozen_string_literal: true

# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
module LeadsHelper
  RATING_STARS = 5

  #----------------------------------------------------------------------------
  def stars_for(lead)
    star = '&#9733;'
    rating = lead.rating.to_i
    (star * rating).html_safe + content_tag(:font, (star * (RATING_STARS - rating)).html_safe, color: 'gainsboro')
  end

  #----------------------------------------------------------------------------
  def link_to_convert(lead)
    link_to(t(:convert), convert_lead_path(lead),
            method: :get,
            with:   "{ previous: crm.find_form('edit_lead') }",
            remote: true)
  end

  #----------------------------------------------------------------------------
  def link_to_reject(lead)
    link_to(t(:reject) + "!", reject_lead_path(lead), method: :put, remote: true)
  end

  #----------------------------------------------------------------------------
  def confirm_reject(lead)
    question = %(<span class="warn">#{t(:reject_lead_confirm)}</span>)
    yes = link_to(t(:yes_button), reject_lead_path(lead), method: :put)
    no = link_to_function(t(:no_button), "$('#menu').html($('#confirm').html());")
    text = "$('#confirm').html( $('#menu').html() );\n"
    text += "$('#menu').html('#{question} #{yes} : #{no}');"
    text.html_safe
  end

  # Sidebar checkbox control for filtering leads by status.
  #----------------------------------------------------------------------------
  def lead_status_checkbox(status, count)
    entity_filter_checkbox(:status, status, count)
  end

  # Returns default permissions intro for leads
  #----------------------------------------------------------------------------
  def get_lead_default_permissions_intro(access)
    case access
    when "Private" then t(:lead_permissions_intro_private, t(:opportunity_small))
    when "Public" then t(:lead_permissions_intro_public, t(:opportunity_small))
    when "Shared" then t(:lead_permissions_intro_shared, t(:opportunity_small))
    end
  end

  # Do not offer :converted status choice if we are creating a new lead or
  # editing existing lead that hasn't been converted before.
  #----------------------------------------------------------------------------
  def lead_status_codes_for(lead)
    if lead.status != "converted" && (lead.new_record? || lead.contact.nil?)
      Setting.unroll(:lead_status).delete_if { |status| status.last == :converted }
    else
      Setting.unroll(:lead_status)
    end
  end

  # Lead summary for RSS/ATOM feed.
  #----------------------------------------------------------------------------
  def lead_summary(lead)
    summary = []
    summary << (lead.status ? t(lead.status) : t(:other))

    if lead.company? && lead.title?
      summary << t(:works_at, job_title: lead.title, company: lead.company)
    else
      summary << lead.company if lead.company?
      summary << lead.title if lead.title?
    end
    summary << "#{t(:referred_by_small)} #{lead.referred_by}" if lead.referred_by?
    summary << lead.email if lead.email.present?
    summary << "#{t(:phone_small)}: #{lead.phone}" if lead.phone.present?
    summary << "#{t(:mobile_small)}: #{lead.mobile}" if lead.mobile.present?
    summary.join(', ')
  end

  # Save the lead along with its permissions.
  #----------------------------------------------------------------------------
  def save_with_permissions(params, lead)
    lead.campaign = Campaign.find(params[:campaign]) unless params[:campaign].blank?
    if params[:lead][:access] == "Campaign" && campaign # Copy campaign permissions.
      save_with_model_permissions(Campaign.find(campaign_id))
    else
      lead.attributes = params[:lead]
      save
    end
  end

  # Update lead attributes taking care of campaign lead counters when necessary.
  #----------------------------------------------------------------------------
  def update_with_lead_counters(attributes, lead)
    if campaign_id == attributes[:campaign_id] # Same campaign (if any).
      lead.attributes = attributes
      save
    else                                            # Campaign has been changed -- update lead counters...
      decrement_leads_count                         # ..for the old campaign...
      lead.attributes = attributes                  # Assign new campaign.
      lead = save
      increment_leads_count                         # ...and now for the new campaign.
      lead
    end
  end

end

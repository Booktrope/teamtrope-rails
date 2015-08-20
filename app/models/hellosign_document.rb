class HellosignDocument < ActiveRecord::Base
  belongs_to :hellosign_document_type
  belongs_to :team_membership

  delegate :name, :template_id, :subject, :message, :ccs, :signers, to: :hellosign_document_type, allow_nil: true

  has_many :hellosign_signatures
  alias :signatures :hellosign_signatures

  def HellosignDocument.send_creative_team_agreement(team_membership)

    creative_team_agreement = HellosignDocumentType.find_by_name("Creative Team Agreement")

    return if creative_team_agreement.nil?

    hellosign_document = creative_team_agreement.hellosign_documents.create!(
      team_membership_id: team_membership.id
    )

    signers = [
      {
        email_address: team_membership.member.email,
        name: team_membership.member.name,
        role: 'Client'
      }
    ]

    custom_fields = {
      role: team_membership.role.name,
      role_description: team_membership.role.contract_description,
      percentage: team_membership.percentage
    }

    hellosign_document.send_agreement(custom_fields, signers)

    hellosign_document
  end

  def send_agreement(custom_fields, signers)

    #send the signature request to hellosign using their api

    #TODO: wrap in a begin/rescue
    response = HelloSign.send_signature_request_with_template(build_hellosign_payload(custom_fields, signers))

    #update the hellosign_id with the guid returned in the response.
    self.update_attributes(
      hellosign_id: response.data['signature_request_id'],
      signing_url: response.data['signing_url'],
      final_copy_uri: response.data['final_copy_uri'],
      details_url: response.data['details_url'],
      is_complete: response.data['is_complete'],
      has_error: response.data['has_error']
    )

    #creating the hellosign signatures that represent the people that must sign this document
    response.data['signatures'].each do | signature |
      self.hellosign_signatures.create!(
        signature_id: signature['signature_id'],
        signer_email_address: signature['signer_email_address'],
        signer_name: signature['signer_name'],
        order: signature['order'],
        status_code: signature['status_code'],
        signed_at: signature['signed_at'],
        last_viewed_at: signature['last_viewed_at'],
        last_reminded_at: signature['last_reminded_at'],
        error: signature['error']
      )
    end
  end

  private
  def build_hellosign_payload(custom_fields, signers, mode = Figaro.env.hello_sign_status)
    {
      test_mode: (mode == 'live')? false : true,
      template_id: template_id,
      subject: subject,
      message: message,
      signers: (signers + self.signers).map(&:deep_symbolize_keys),
      ccs: self.ccs.map(&:deep_symbolize_keys),
      custom_fields: custom_fields.deep_symbolize_keys
    }
  end

  # Make use of the Sanitizer which will use the config to get the correct recipients
  # and use them, but only if active.
  def HellosignDocument.sanitize_address(original_address, type)
    # Fake a message & pass it into the sanitizer
    mail       = Mail.new
    mail[:to]  = original_address
    mail[:cc]  = original_address
    mail[:bcc] = original_address
    sanitizer  = SanitizeEmail::OverriddenAddresses.new(mail)

    # Grab the sanitized address.  This method does not return the friendly name containing
    # the original address which HelloSign chokes on.
    sanitizer.send("sanitized_#{type}")
  end
end

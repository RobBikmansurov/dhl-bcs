module Dhl::Bcs::V3
  class Shipment

    attr_accessor :shipper, :receiver, :bank_data, :shipment_date,
                  :customer_reference, :services, :weight, :length, :height, :width,
                  :notification_email, :export_document, :return_shipment_reference
    attr_reader :product

    PRODUCT_PROCEDURE_NUMBERS = {
      'V01PAK' => '01', # DHL Paket
      'V01PRIO' => '01', # DHL Paket Prio
      'V06PAK' => '06', # DHL Paket Taggleich
      'V53WPAK' => '53', # DHL Paket International
      'V54EPAK' => '54', # DHL Europaket
      'V55PAK' => '55', # DHL Paket Connect
      'V06TG' => '01', # DHL Kurier Taggleich
      'V06WZ' => '01', # DHL Kurier Wunschzeit
      'V86PARCEL' => '86', # DHL Paket Austria
      'V87PARCEL' => '87', # DHL PAKET Connect
      'V82PARCEL' => '82' # DHL PAKET International
    }.freeze
    PRODUCTS = PRODUCT_PROCEDURE_NUMBERS.keys.freeze

    # build a shipment from hash data
    def self.build(attributes = {})
      attributes = attributes.dup
      shipper = attributes[:shipper]
      receiver = attributes[:receiver]
      bank_data = attributes[:bank_data]
      export_document = attributes[:export_document]
      new(attributes.merge(shipper: shipper, receiver: receiver, bank_data: bank_data, export_document: export_document))
    end

    def initialize(attributes = {})
      assign_attributes(
        {
          product: 'V01PAK',
          shipment_date: Date.today,
          services: []
        }.merge(attributes)
      )
    end

    def assign_attributes(attributes)
      attributes.each do |key, value|
        setter = :"#{key}="
        send(setter, value) if respond_to?(setter)
      end
    end

    def product=(product)
      raise Dhl::Bcs::Error, "No valid product code #{product}. Please use one of these: #{PRODUCTS.join(', ')}" unless PRODUCTS.include?(product)
      @product = product
    end

    def to_soap_hash(ekp, participation_number)
      raise Dhl::Bcs::Error, 'Packing weight in kilo must be set!' unless weight
      raise Dhl::Bcs::Error, 'Sender address must be set!' unless shipper
      raise Dhl::Bcs::Error, 'Receiver address must be set!' unless receiver
      raise Dhl::Bcs::Error, 'Product must be set!' unless product
      raise Dhl::Bcs::Error, 'In order to do an international shipment --product:V53WPAK--, :export_document must be set!' if (product == 'V53WPAK') ^ export_document

      account_number = "#{ekp}#{PRODUCT_PROCEDURE_NUMBERS[product]}#{participation_number}"
      raise Dhl::Bcs::Error, 'Need a 14 character long account number. Check EKP and participation_number' if account_number.size != 14
      {
        'ShipmentDetails' => {}.tap { |h|
          h['product'] = product
          h['shipmentDate'] = shipment_date.strftime("%Y-%m-%d")
          h['cis:accountNumber'] = account_number
          h['customerReference'] = customer_reference if !customer_reference.blank?
          h['return_shipment_reference'] = return_shipment_reference if !return_shipment_reference.blank?

          # just one ShipmentItem possible
          h['ShipmentItem'] = { 'weightInKG' => weight }.tap { |si|
            si['lengthInCM'] = length if length
            si['widthInCM'] = width if width
            si['heightInCM'] = height if height
          }
          h['Service'] = services.map(&:to_soap_hash) unless services.empty?
          h['Notification'] = { 'recipientEmailAddress' => notification_email } if notification_email
          h['BankData'] = bank_data.to_soap_hash if bank_data
        },
        # Shipper information
        'Shipper' => shipper.to_soap_hash,
        # Receiver information
        'Receiver' => receiver.to_soap_hash
      }.tap{|h|
          #ExportDocument information
        h['ExportDocument'] = export_document.to_soap_hash if export_document
      }
    end

  end
end

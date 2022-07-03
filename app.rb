require "functions_framework"
require "google/cloud/firestore"
require 'json'
require 'set'

ISO_CURRENCIES = Set.new(["afn", "eur", "all", "dzd", "usd", "aoa", "xcd", "ars", "amd", "awg", "aud", "azn", "bhd", "bsd", "bdt", "bbd", "byn", "bzd", "xof", "bmd", "inr", "btn", "bob", "bov", "bam", "bwp", "nok", "brl", "bnd", "bgn", "bif", "cve", "khr", "xaf", "cad", "kyd", "clp", "clf", "cny", "cop", "cou", "kmf", "cdf", "nzd", "crc", "hrk", "cup", "cuc", "ang", "czk", "dkk", "djf", "dop", "egp", "svc", "ern", "szl", "etb", "fkp", "fjd", "xpf", "gmd", "gel", "ghs", "gip", "gtq", "gbp", "gnf", "gyd", "htg", "hnl", "hkd", "huf", "isk", "idr", "xdr", "irr", "iqd", "ils", "jmd", "jpy", "jod", "kzt", "kes", "kpw", "krw", "kwd", "kgs", "lak", "lbp", "lsl", "zar", "lrd", "lyd", "chf", "mop", "mkd", "mga", "mwk", "myr", "mvr", "mru", "mur", "xua", "mxn", "mxv", "mdl", "mnt", "mad", "mzn", "mmk", "nad", "npr", "nio", "ngn", "omr", "pkr", "pab", "pgk", "pyg", "pen", "php", "pln", "qar", "ron", "rub", "rwf", "shp", "wst", "stn", "sar", "rsd", "scr", "sll", "sgd", "xsu", "sbd", "sos", "ssp", "lkr", "sdg", "srd", "sek", "che", "chw", "syp", "twd", "tjs", "tzs", "thb", "top", "ttd", "tnd", "try", "tmt", "ugx", "uah", "aed", "usn", "uyu", "uyi", "uyw", "uzs", "vuv", "ves", "vnd", "yer", "zmw", "zwl", "xba", "xbb", "xbc", "xbd", "xts", "xxx", "xau", "xpd", "xpt", "xag", "afa", "fim", "alk", "adp", "esp", "frf", "aok", "aon", "aor", "ara", "arp", "ary", "rur", "ats", "aym", "azm", "byb", "byr", "bec", "bef", "bel", "bop", "bad", "brb", "brc", "bre", "brn", "brr", "bgj", "bgk", "bgl", "buk", "hrd", "cyp", "csj", "csk", "ecs", "ecv", "gqe", "eek", "xeu", "gek", "ddm", "dem", "ghc", "ghp", "grd", "gne", "gns", "gwe", "gwp", "itl", "isj", "iep", "ilp", "ilr", "laj", "lvl", "lvr", "lsm", "zal", "ltl", "ltt", "luc", "luf", "lul", "mgf", "mvq", "mlf", "mtl", "mtp", "mro", "mxp", "mze", "mzm", "nlg", "nic", "peh", "pei", "pes", "plz", "pte", "rok", "rol", "std", "csd", "skk", "sit", "rhd", "esa", "esb", "sdd", "sdp", "srg", "chc", "tjr", "tpe", "trl", "tmm", "ugs", "ugw", "uak", "sur", "uss", "uyn", "uyp", "veb", "vef", "vnc", "ydd", "yud", "yum", "yun", "zrn", "zrz", "zmk", "zwc", "zwd", "zwn", "zwr", "xfo", "xre", "xfu"]).freeze

class Object
  def blank?; self.nil? || self.empty?; end
end

class Settings
  def self.app
    @app ||= ::YAML.load_file('config/application.yml', symbolize_names: true)[env]
  end

  def self.env
    @env ||= (ENV['RACK_ENV'] || 'development').to_sym
  end

  def self.fake_db?
    return @fake_db if defined?(@fake_db)
    @fake_db = ENV['FAKE_DB']
  end
end

firestore = Google::Cloud::Firestore.new(
  project_id: Settings.app[:google_project_id],
  credentials: "./config/google_key.json"
)

FunctionsFramework.http "put_expense" do |request|
  begin
    input = JSON.parse request.body.read rescue {}
    spend_event = input['spend_event']
    missed_fields_err = validate_fields(spend_event)
    raise StandardError.new(missed_fields_err) if !missed_fields_err.blank?

    db_event = { user_name: spend_event['user_name'], amount: spend_event['amount'].strip.to_f, created_at: Time.now.to_i,
                 currency: spend_event['currency'].strip.downcase, category: spend_event['category'].strip.downcase, place: spend_event['place']&.strip }
    puts db_event.inspect
    response = create_record(db_event, firestore, Settings.app[:firestore_table_name])
    # response = OpenStruct.new(update_time: DateTime.now)
    return { status: 200, message: 'Saved!', event_saved_at: response.update_time.to_s }
  rescue Exception => ex
    puts ex.inspect
    return { status: 500, message: ex.message }
  end
end

private

def create_record(db_event, database, table_name)
  Settings.fake_db? ? OpenStruct.new(update_time: DateTime.now) : database.col(table_name).doc.set(db_event)
end

def validate_fields(spend_event)
  amount = spend_event['amount']
  currency = spend_event['currency']

  missed_fields_err = ''
  missed_fields_err << 'Username is missed! ' if spend_event['user_name'].blank?
  missed_fields_err << 'Amount is missed! ' if amount.blank?
  Float(amount) rescue (missed_fields_err << 'Amount should be a number! ')
  missed_fields_err << 'Currency is missed! ' if currency.blank?
  missed_fields_err << "Currency Name should an ISO 4217 Code, example 'USD'! " unless ISO_CURRENCIES.include?(currency.downcase)
  missed_fields_err << 'Category is missed! ' if spend_event['category'].blank?
  missed_fields_err.strip
end

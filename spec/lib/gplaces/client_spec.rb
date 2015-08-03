require "webmock/rspec"

RSpec.describe Gplaces::Client do
  let(:client) { Gplaces::Client.new("API") }

  describe "#autocomplete" do
    before do
      stub_request(:get, "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Vict&key=API")
        .to_return(fixture("autocomplete.json"))
      stub_request(:get, "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=Vict&key=INVALID")
        .to_return(fixture("error_request_denied.json"))
    end

    it "returns a list of predictions" do
      predictions = client.autocomplete("Vict")
      expect(predictions).to be_a(Array)
      expect(predictions.first).to be_a(Gplaces::Prediction)
    end

    describe "error handling" do
      it "throws an error when API KEY is invalid" do
        client = Gplaces::Client.new("INVALID")
        expect { client.autocomplete("Vict") }.to raise_error(Gplaces::RequestDeniedError)
      end

      it "verifies if input is valid before request" do
        client = Gplaces::Client.new("Valid")
        expect { client.autocomplete("") }.to raise_error(Gplaces::InvalidRequestError)
      end
    end
  end

  describe "#details" do
    before do
      stub_request(:get, "https://maps.googleapis.com/maps/api/place/details/json?key=API&language=en" \
                         "&placeid=ChIJl-emOTauEmsRVuhkf-gObv8")
        .to_return(fixture("details.json"))
    end

    it "gets the place details" do
      expect(client.details("ChIJl-emOTauEmsRVuhkf-gObv8", "en").city).to eq("Pyrmont")
    end

    context "when place details are not available" do
      before do
        stub_request(:get, "https://maps.googleapis.com/maps/api/place/details/json?key=API&language=en" \
                           "&placeid=ChIJl-emOTauEmsRVuhkf-gObv8")
          .to_return(fixture("error_not_found.json"))
      end

      it "throws an error" do
        expect { client.details("ChIJl-emOTauEmsRVuhkf-gObv8", "en") }.to raise_error(Gplaces::NotFoundError)
      end
    end
  end

  describe "#details_multi" do
    it "requests all of the given places details" do
      # Stubbing curl multi request is currently not supported in Webmock...
      expect(Curl::Multi).to receive(:get).with(
        %w(
          https://maps.googleapis.com/maps/api/place/details/json?key=API&placeid=foo&language=en
          https://maps.googleapis.com/maps/api/place/details/json?key=API&placeid=bar&language=en
        ),
        any_args
      )
      client.details_multi(*%w(foo bar), "en")
    end

    it "uses http pipelining" do
      expect(Curl::Multi).to receive(:get).with(
        any_args,
        pipeline: true
      )
      client.details_multi(*%w(foo bar), "en")
    end

    it "creates places" do
      allow(Curl::Multi).to receive(:get).and_yield(double(body: '{"result":{"place_id":"foo"},"status":"OK"}'))
                                         .and_yield(double(body: '{"result":{"place_id":"bar"},"status":"OK"}'))

      client.details_multi(*%w(foo bar), "en").tap do |places|
        expect(places.count).to eq(2)
        expect(places.map(&:place_id)).to eq(%w(foo bar))
      end
    end

    context "when place details are not available" do
      it "skips place in question" do
        allow(Curl::Multi).to receive(:get).and_yield(double(body: '{"result":{"place_id":"foo"},"status":"OK"}'))
                                           .and_yield(double(body: '{"status":"NOT_FOUND"}'))

        client.details_multi(*%w(foo bar), "en").tap do |places|
          expect(places.count).to eq(2)
          expect(places.first.place_id).to eq("foo")
          expect(places.last).to eq(nil)
        end
      end
    end
  end
end

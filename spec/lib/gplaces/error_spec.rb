RSpec.describe Gplaces::Error do
  it "forward error for now" do
    begin
      fail Gplaces::Error, "Error!"
    rescue Gplaces::Error => error
      expect(error.message).to eq("Error!")
    end
  end
end

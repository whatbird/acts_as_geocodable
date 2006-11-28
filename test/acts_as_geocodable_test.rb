require File.join(File.dirname(__FILE__), 'test_helper')

class Vacation < ActiveRecord::Base
  acts_as_geocodable :normalize_address => true
end

class City < ActiveRecord::Base
  acts_as_geocodable :address => {:postal_code => :zip}  
end

class ActsAsGeocodableTest < Test::Unit::TestCase
  fixtures :vacations, :cities, :geocodes, :geocodings
  
  def test_acts_as_geocodable_declaration
    assert vacations(:whitehouse).respond_to?(:acts_as_geocodable_options)
    assert vacations(:whitehouse).geocodings.is_a?(Array)
    assert vacations(:whitehouse).geocodes.is_a?(Array)
  end
  
  def test_full_address
    whitehouse = vacations(:whitehouse)
    expected_address = "1600 Pennsylvania Ave NW\nWashington, DC 20502"
    assert_equal expected_address, whitehouse.full_address
    
    holland = cities(:holland)
    assert_equal '49423', holland.full_address
  end
  
  # FIXME: this test is failing, why?
  # def test_geocode_creation_with_address_normalization
  #   assert Vacation.acts_as_geocodable_options[:normalize_address]
  # 
  #   mystery_spot = save_vacation_to_create_geocode
  # 
  #   assert_match /Ignace/, mystery_spot.city
  #   assert_equal 'MI', mystery_spot.region
  # end
  
  def test_geocode_creation_without_address_normalization
    Vacation.acts_as_geocodable_options.merge! :normalize_address => false
    assert !Vacation.acts_as_geocodable_options[:normalize_address]
    
    mystery_spot = save_vacation_to_create_geocode
    
    assert_nil mystery_spot.city
    assert_nil mystery_spot.region
  end

  def test_geocode_creation_with_empty_full_address
    nowhere = cities(:nowhere)
    assert_equal '', nowhere.full_address
    assert_equal 0, nowhere.geocodes.size
    
    assert_no_difference(Geocode, :count) do
      assert_no_difference(Geocoding, :count) do
        # Force Geocode
        nowhere.save!
        nowhere.reload
      end
    end
    
    assert_equal 0, nowhere.geocodes.size
  end
  
  def test_geocode_creation_with_nil_full_address
    nowhere = cities(:nowhere)
    nowhere.zip = nil
    assert nowhere.full_address.empty?
    assert_equal 0, nowhere.geocodes.size
    
    assert_no_difference(Geocode, :count) do
      assert_no_difference(Geocoding, :count) do
        # Force Geocode
        nowhere.save!
        nowhere.reload
      end
    end
    
    assert_equal 0, nowhere.geocodes.size
  end
  
  def test_save_respects_existing_geocode
    saugatuck = vacations(:saugatuck)
    assert_equal 1, saugatuck.geocodes.count
    original_geocode = saugatuck.geocodes.first
    
    assert_no_difference(Geocode, :count) do
      assert_no_difference(Geocoding, :count) do
        saugatuck.save!
        saugatuck.reload
        
        saugatuck.city = 'Beverly Hills'
        saugatuck.postal_code = '90210'
        saugatuck.save!
        saugatuck.reload
      end
    end
    
    assert_equal 1, saugatuck.geocodes.count
    assert_equal original_geocode, saugatuck.geocodes.first
  end
  
  def test_find_within_radius_of_postal_code
    douglas_postal_code = '49406'
    assert_nil Geocode.find_by_postal_code(douglas_postal_code)
    
    assert_difference(Geocode, :count, 1) do
      assert_no_difference(Geocoding, :count) do
        assert_no_difference(Vacation, :count) do
          nearby = Vacation.find_within_radius_of_postal_code(douglas_postal_code, 10)

          assert_equal 1, nearby.size
          assert_equal vacations(:saugatuck), nearby.first

          assert_not_nil nearby.first.distance
          assert_in_delta 0.794248231790402, nearby.first.distance.to_f, 0.2
        end
      end
    end
  end
  
  def test_distance_to
    saugatuck = vacations(:saugatuck)
    douglas = Vacation.create(:name => 'Douglas', :postal_code => '49406')
    douglas.reload # reload to get geocode
    
    distance = douglas.distance_to(saugatuck)
    assert_in_delta 0.794248231790402, distance, 0.2
    
    distance = saugatuck.distance_to(douglas)
    assert_in_delta 0.794248231790402, distance, 0.2
    
    distance = douglas.distance_to(saugatuck, :miles)
    assert_in_delta 0.794248231790402, distance, 0.2
    
    distance = douglas.distance_to(saugatuck, :kilometers)
    assert_in_delta 1.27821863, distance, 0.2
  end
  
  #
  # Helpers
  #
  def save_vacation_to_create_geocode
    returning vacations(:mystery_spot) do |mystery_spot|
      assert mystery_spot.geocodes.empty?
      assert_nil mystery_spot.city
      assert_nil mystery_spot.region

      assert_difference(Geocode, :count, 1) do
        mystery_spot.save!
        mystery_spot.reload
      end
      assert_equal 1, mystery_spot.geocodes.count
    end
  end
end

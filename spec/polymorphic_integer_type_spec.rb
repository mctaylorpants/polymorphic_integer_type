require 'spec_helper'

describe PolymorphicIntegerType do
  let(:owner) { Person.create(name: "Kyle") }
  let(:dog) { Animal.create(name: "Bela", kind: "Dog", owner: owner) }
  let(:cat) { Animal.create(name: "Alexi", kind: "Cat") }

  let(:kibble) { Food.create(name: "Kibble") }
  let(:chocolate) { Food.create(name: "Choclate") }

  let(:milk) { Drink.create(name: "milk") }
  let(:water) { Drink.create(name: "Water") }
  let(:whiskey) { Drink.create(name: "Whiskey") }

  let(:link) { Link.create(source: source, target: target) }

  context "when the source is nil" do
    let(:source) { nil }
    let(:target) { nil }
    it "should have the no id/type for the source" do
      expect(link.source_id).to be_nil
      expect(link.source_type).to be_nil
      expect(link.source).to be_nil
    end
  end

  context "when the source is a class that modifies the sti_name" do
    it "properly sets the source_type to the modified class name" do
      link = Link.new(source: Namespaced::Animal.new)
      expect(link.source_type).to eql "Animal"
    end
  end

  context "when querying the associations" do
    let(:source) { cat }
    let(:target) { nil }
    it "properly finds the object with a where" do
      expect(Link.where(source: source, id: link.id).first).to eql link
    end
    it "properly finds the object with a find_by" do
      expect(Link.find_by(source: source, id: link.id)).to eql link
    end
  end

  shared_examples "proper source" do
    it "should have the proper id, type and object for the source" do
      expect(link.source_id).to eql source.id
      expect(link.source_type).to eql source.class.to_s
      expect(link.source).to eql source
    end
  end

  shared_examples "proper target" do
    it "should have the proper id, type and object for the target" do
      expect(link.target_id).to eql target.id
      expect(link.target_type).to eql target.class.to_s
      expect(link.target).to eql target
    end
  end

  context "When a link is created through an association" do
    let(:link) { source.source_links.create }
    let(:source) { cat }
    include_examples "proper source"

    context "and the link is accessed through the associations" do
      before { link }

      it "should have the proper source" do
        expect(source.source_links[0].source).to eql source
      end
    end

  end
  context "When a link is given polymorphic record" do
    let(:link) { Link.create(source: source) }
    let(:source) { cat }
    include_examples "proper source"

    context "and when it already has a polymorphic record" do
      let(:target) { kibble }
      before { link.update_attributes(target: target) }

      include_examples "proper source"
      include_examples "proper target"

    end

  end

  context "When a link is given polymorphic id and type" do
    let(:link) { Link.create(source_id: source.id, source_type: source.class.to_s) }
    let(:source) { cat }
    include_examples "proper source"

    context "and when it already has a polymorphic id and type" do
      let(:target) { kibble }
      before { link.update_attributes(target_id: target.id, target_type: target.class.to_s) }
      include_examples "proper source"
      include_examples "proper target"

    end

  end

  context "When using a relation to the links with eagar loading" do
    let!(:links){
      [Link.create(source: source, target: kibble),
        Link.create(source: source, target: water)]
    }
    let(:source) { cat }

    it "should be able to return the links and the targets" do
      expect(cat.source_links).to match_array links
      expect(cat.source_links.includes(:target).collect(&:target)).to match_array [water, kibble]

    end

  end

  context "When using a through relation to the links with eagar loading" do
    let!(:links){
      [Link.create(source: source, target: kibble),
        Link.create(source: source, target: water)]
    }
    let(:source) { dog }

    it "should be able to return the links and the targets" do
      expect(owner.pet_source_links).to match_array links
      expect(owner.pet_source_links.includes(:target).collect(&:target)).to match_array [water, kibble]

    end

  end

  context "When eagar loading the polymorphic association" do
    let(:link) { Link.create(source_id: source.id, source_type: source.class.to_s) }
    let(:source) { cat }

    context "and when there are multiples sources" do
      let(:link_2) { Link.create(source_id: source_2.id, source_type: source_2.class.to_s) }
      let(:source_2) { dog }
      it "should be able to preload both associations" do
        links = Link.includes(:source).where(id: [link.id, link_2.id]).order(:id)
        expect(links.first.source).to eql cat
        expect(links.last.source).to eql dog
      end

    end

    it "should be able to preload the association" do
      l = Link.includes(:source).where(id: link.id).first
      expect(l.source).to eql cat
    end


  end

  context "when the association is an STI table" do
    let(:link) { Link.create(source: source, target: whiskey) }
    let(:source) { Dog.create(name: "Bela", kind: "Dog", owner: owner) }
    it "should have the proper id, type and object for the source" do
      expect(link.source_id).to eql source.id
      expect(link.source_type).to eql "Animal"
      expect(link.source).to eql source
    end
  end

  context "when mapping is given inline in the belongs_to model" do
    class InlineLink < ActiveRecord::Base
      include PolymorphicIntegerType::Extensions

      self.table_name = "links"

      belongs_to :source, polymorphic: {10 => "Person", 11 => "InlineAnimal"}
      belongs_to :target, polymorphic: {10 => "Food", 13 => "InlineDrink"}
      belongs_to :normal_target, polymorphic: true
    end

    class InlineAnimal < ActiveRecord::Base
      include PolymorphicIntegerType::Extensions

      self.table_name = "animals"

      belongs_to :owner, class_name: "Person"
      has_many :source_links, as: :source, class_name: "InlineLink"
    end

    class InlineDrink < ActiveRecord::Base
      include PolymorphicIntegerType::Extensions

      self.table_name = "drinks"

      has_many :inline_links, as: :target
    end

    let!(:animal) { InlineAnimal.create!(name: "Lucy") }
    let!(:drink) { InlineDrink.create!(name: "Water") }
    let!(:link) { InlineLink.create!(source: animal, target: drink, normal_target: drink) }

    let(:source) { animal }
    let(:target) { drink }

    include_examples "proper source"
    include_examples "proper target"

    it "creates foreign_type mapping method" do
      expect(Link.source_type_mapping).to eq({1 => "Person", 2 => "Animal"})
      expect(InlineLink.source_type_mapping).to eq({10 => "Person", 11 => "InlineAnimal"})
    end

    it "pulls mapping from given hash" do
      expect(link.source_id).to eq(animal.id)
      expect(link[:source_type]).to eq(11)
      expect(link.target_id).to eq(drink.id)
      expect(link[:target_type]).to eq(13)
    end

    it "doesn't break string type polymorphic associations" do
      expect(link.normal_target).to eq(drink)
      expect(link.normal_target_type).to eq("InlineDrink")
    end
  end

  context "when mapping assigned to `polymorphic` option on belongs_to model" do
    class InlineLink2 < ActiveRecord::Base
      include PolymorphicIntegerType::Extensions

      self.table_name = "links"

      belongs_to :source, polymorphic: {10 => "Person", 11 => "InlineAnimal2"}
      belongs_to :target, polymorphic: {10 => "Food", 13 => "InlineDrink2"}
      belongs_to :normal_target, polymorphic: true
    end

    class InlineAnimal2 < ActiveRecord::Base
      include PolymorphicIntegerType::Extensions

      self.table_name = "animals"

      has_many :source_links, as: :source, class_name: "InlineLink2"
    end

    class InlineDrink2 < ActiveRecord::Base
      include PolymorphicIntegerType::Extensions

      self.table_name = "drinks"

      has_many :inline_links2, as: :target
    end

    let!(:animal) { InlineAnimal2.create!(name: "Lucy") }
    let!(:drink) { InlineDrink2.create!(name: "Water") }
    let!(:link) { InlineLink2.create!(source: animal, target: drink, normal_target: drink) }

    let(:source) { animal }
    let(:target) { drink }

    include_examples "proper source"
    include_examples "proper target"

    it "pulls mapping from given hash" do
      expect(link.source_id).to eq(animal.id)
      expect(link[:source_type]).to eq(11)
      expect(link.target_id).to eq(drink.id)
      expect(link[:target_type]).to eq(13)
    end

    it "doesn't break string type polymorphic associations" do
      expect(link.normal_target).to eq(drink)
      expect(link.normal_target_type).to eq("InlineDrink2")
    end
  end
end

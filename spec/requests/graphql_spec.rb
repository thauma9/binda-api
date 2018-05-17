require "rails_helper"

describe "GraphQL API" do
  
  before(:context) do
		@structure = create(:article_structure_with_components_and_fields)
    @structure.components.each do |component|
      component.strings.each{|string| string.update(content: "Content of string #{string.field_setting.slug}") }
    end
		@component = @structure.components.first
  end

  it "returns structures" do
    data = '{
      structures{
        edges{
          node{
            id
            name
          }
        }
      }
    }'
    post graphql_path(query: data)
    
    expect(response).to be_success
    expect(json['data']).to have_key 'structures'
    expect(json['data']['structures']['edges'].size).to eq(3)
  end

  it "returns components" do
    data = '{
      components{
        edges{
          node{
            id
            name
            slug
            string:get_string(slug: "1-field-setting"){
              value
            }
          }
        }
      }
    }'
    post graphql_path(query: data)
    expect(response).to be_success
    expect(json['data']).to have_key 'components'
    expect(json['data']['components']['edges'].size).to eq(3)
  end

  it "returns a board by its slug" do
    
    data = '{
      board_by_slug(slug: "dashboard"){
        name
      }
    }'
    post graphql_path(query: data)
    expect(response).to be_success
    expect(json['data']).to have_key 'board_by_slug'
    expect(json['data']['board_by_slug']['name']).to eq 'dashboard'
  end
  
  it "returns a dynamic string field" do
    data = '{
      components{
        edges{
          node{
            id
            name
            slug
            string:get_string(slug: "1-field-setting"){
              value
            }
          }
        }
      }
    }'
    post graphql_path(query: data)
    json['data']['components']['edges'].each do |component|
      expect(component['node']['string']['value']).to eq "Content of string 1-field-setting"
    end
  end

  it "returns repeater's dynamic fields ordered by position" do
    component = Binda::Component.last
    repeater = component.repeaters.first
    string = repeater.strings.first
    component.repeaters.create({ field_setting_id: repeater.field_setting.id })
    component.repeaters.order("position").first.strings.first.update content: "Content of first repeater"
    component.repeaters.order("position").last.strings.first.update content: "Content of last repeater"
    data = '{
      components{
        edges{
          node{
            id
            slug
            repeaters(slug: "'+repeater.field_setting.slug+'"){
              string:get_string(slug: "'+string.field_setting.slug+'"){
                value
              }
            }
          }
        }
      }
    }'
    post graphql_path(query: data)
    component = json['data']['components']['edges'].first['node']
    expect(component['repeaters'].count).to eq 2
    expect(component['repeaters'].last['string']['value']).to eq "Content of last repeater"
  end

  it "returns blank for a dynamic string field that doesn't exist" do
    data = '{
      components{
        edges{
          node{
            id
            name
            slug
            string:get_string(slug: "missing-field-setting"){
              value
            }
          }
        }
      }
    }'
    post graphql_path(query: data)
    json['data']['components']['edges'].each do |component|
      expect(component['node']['string']['value']).to eq ""
    end
  end

  it "get all choices from a checkbox as a array" do 
    checkbox_setting = @structure.field_groups.first.field_settings.create({ field_type: "checkbox", name: "A checkbox" })
    checkbox = Binda::Checkbox.where(
      fieldable_id: @component.id,
      field_setting_id: checkbox_setting
    ).first
    for i in 0..2
      choice = checkbox_setting.choices.create({ label: "label #{i}", value: "value #{i}" })
      checkbox.choices << choice
    end
    data = "{
      components(slug: \"#{@component.slug}\") {
        edges {
          node {
            checkbox_choices: get_checkbox_choices(slug: \"#{checkbox_setting.slug}\") {
              value
              label
            }
          }
        }
      }
    }"
    post graphql_path(query: data)
    edges = json['data']['components']['edges']
    expect(edges.first['node']['checkbox_choices'].count).to eq(3)
    edges.each do |edge| 
      edge['node']['checkbox_choices'].each_with_index do |choice, i|
        expect(choice['value']).to eq("value #{i}")
      end
    end
  end

end


class NetgalleySubmission < ActiveRecord::Base
  belongs_to :project

  after_initialize :custom_init
  serialize :category, Array

  delegate :imprint_name, to: :project, allow_nil: true

  alias :imprint :imprint_name

  CATEGORIES = [
    "Arts & Photography",
    "Biographies & Memoirs",
    "Business & Investing",
    "Children's Fiction",
    "Children's Nonfiction",
    "Christian",
    "Comics & Graphic",
    "Computers & Internet",
    "Cooking, Food & Wine",
    "Crafts & Hobbies",
    "Entertainment",
    "Erotica",
    "General Fiction (Adult)",
    "Health, Mind & Body",
    "History",
    "Home & Garden",
    "Horror",
    "Humor",
    "LGBTQIA",
    "Literary Fiction",
    "Middle Grade",
    "Mystery & Thrillers",
    "New Adult",
    "Nonfiction (Adult)",
    "Outdoors & Nature",
    "Parenting & Families",
    "Poetry",
    "Politics",
    "Professional & Technical",
    "Reference",
    "Religion & Spirituality",
    "Romance",
    "Sci Fi & Fantasy",
    "Science",
    "Self-Help",
    "Sports",
    "Teens & YA",
    "Travel",
    "Women's Fiction"
  ]

  def custom_init
    return if project.nil?

    self.title ||= project.final_title
    self.author_name ||= project.authors.first.member.display_name
    self.retail_price ||= project.publication_fact_sheet.ebook_price
    self.publication_date ||= project.published_file.publication_date
    self.isbn ||= project.try(:control_number).try(:epub_isbn)
    self.blurb ||= project.try(:draft_blurb).try(:draft_blurb)
  end
end

class User < ApplicationRecord
  acts_as_paranoid
  ratyrate_rater
  devise :database_authenticatable, :registerable, :rememberable, :validatable,
    :omniauthable, omniauth_providers: [:google_oauth2]
  before_save :email_downcase
  enum role: %i(user admin)

  has_many :borrows, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :active_relationships, class_name: Relationship.name,
    foreign_key: "follower_id", dependent: :destroy
  has_many :passive_relationships, class_name: Relationship.name,
    foreign_key: "followed_id", dependent: :destroy
  has_many :following, through: :active_relationships, source: :followed
  has_many :followers, through: :passive_relationships, source: :follower
  has_many :follow_books, dependent: :destroy
  has_many :following_books, through: :follow_books, source: :book
  has_many :like_books, dependent: :destroy
  has_many :liking_books, through: :like_books, source: :book
  has_many :notifications, dependent: :destroy

  validates :name, presence: true, length: {maximum: 50}
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, length: {maximum: 255},
    format: {with: VALID_EMAIL_REGEX}, uniqueness: {case_sensitive: false}
  validates :password, presence: true, length: {minimum: 6}, allow_nil: true

  default_scope -> {order(created_at: :desc)}
  scope :select_attr, ->{select(:id, :name, :email, :role)}
  scope :search_scope, ->(search){where "name like '%#{search}%' or email like '%#{search}%'"}

  def gravatar_url options = {size: Settings.gravatar}
    gravatar_id = Digest::MD5.hexdigest email.downcase
    size = options[:size]
    "https://secure.gravatar.com/avatar/#{gravatar_id}?s=#{size}"
  end

  class << self
    def digest string
      cost =
        if ActiveModel::SecurePassword.min_cost
          BCrypt::Engine::MIN_COST
        else
          BCrypt::Engine.cost
        end
      BCrypt::Password.create string, cost: cost
    end

    def search search
      if search
        search_scope search
      else
        User.select_attr
      end
    end

    def to_csv
      CSV.generate do |csv|
        attributes = %w{id name email role}
        csv << attributes
        all.each do |user|
          csv << user.attributes.values_at(*attributes)
        end
      end
    end

    def from_omniauth auth
      where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
        user.name = auth.info.name
        user.email = auth.info.email
        charset = Array('A'..'Z') + Array('a'..'z')
        user.password = Array.new(6){charset.sample}.join
        user.oauth_token = auth.credentials.token
        user.expires = auth.credentials.expires
        user.oauth_expires_at = auth.credentials.expires_at
        user.refresh_token = auth.credentials.refresh_token
      end
    end
  end

  def feed
    Book.where "category_id IN (SELECT category_id FROM books JOIN follow_books
      ON books.id = follow_books.book_id WHERE follow_books.user_id = ?)", id
  end

  def categories_of_feed
    Category.where "id IN (SELECT category_id FROM books JOIN follow_books
      ON books.id = follow_books.book_id WHERE follow_books.user_id = ?)", id
  end

  def follow other_user
    following << other_user
  end

  def unfollow other_user
    following.delete other_user
  end

  def following? other_user
    following.include? other_user
  end

  def follow_book book
    following_books << book
  end

  def unfollow_book book
    following_books.delete book
  end

  def following_book? book
    following_books.include? book
  end

  def like_book book
    liking_books << book
  end

  def dislike_book book
    liking_books.delete book
  end

  def liking? book
    liking_books.include? book
  end

  private

  def email_downcase
    email.downcase!
  end
end

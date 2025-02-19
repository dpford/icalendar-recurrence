require 'ice_cube'

module Icalendar
  module Recurrence
    class Occurrence < Struct.new(:start_time, :end_time, :parent)
    end

    class Schedule
      attr_reader :event

      def initialize(event)
        @event = event
      end

      def timezone
        event.tzid
      end

      def rrules
        event.rrule
      end

      def start_time
        TimeUtil.to_time(event.start)
      end

      def end_time
        if event.end
          TimeUtil.to_time(event.end)
        else
          start_time + convert_duration_to_seconds(event.duration)
        end
      end

      def occurrences_between(begin_time, closing_time, spans: false)
        ice_cube_occurrences = ice_cube_schedule.occurrences_between(TimeUtil.to_time(begin_time), TimeUtil.to_time(closing_time), spans: spans)

        ice_cube_occurrences.map do |occurrence|
          convert_ice_cube_occurrence(occurrence)
        end
      end

      def all_occurrences
        ice_cube_occurrences = ice_cube_schedule.all_occurrences

        ice_cube_occurrences.map do |occurrence|
          convert_ice_cube_occurrence(occurrence)
        end
      end

      def convert_ice_cube_occurrence(ice_cube_occurrence)
        start_time = ice_cube_occurrence.start_time.utc
        end_time = ice_cube_occurrence.end_time.utc

        Icalendar::Recurrence::Occurrence.new(start_time, end_time, @event)
      end

      def ice_cube_schedule
        schedule = IceCube::Schedule.new
        schedule.start_time = start_time
        schedule.end_time = end_time

        rrules.each do |rrule|
          ice_cube_recurrence_rule = IceCube::Rule.from_ical(rrule.value_ical)
          schedule.add_recurrence_rule(ice_cube_recurrence_rule)
        end

        event.exdate.each do |exception_date_or_dates|
          extracted_exdates = exception_date_or_dates.is_a?(Array) ? exception_date_or_dates : [exception_date_or_dates]
          extracted_exdates.each do |exception_date|
            # exception times should have the same tz offset as the event start or they'll be ignored as different times
            # ignored if ActiveSupport::TimeWithZone is available
            schedule.add_exception_time(TimeUtil.to_time(exception_date, moment: start_time))
          end
        end

        event.rdate.each do |extra_date_or_dates|
          Array(extra_date_or_dates).each do |extra_date|
            # exception times should have the same tz offset as the event start or they'll be ignored as different times
            # ignored if ActiveSupport::TimeWithZone is available
            schedule.add_recurrence_time(TimeUtil.to_time(extra_date, moment: start_time))
          end
        end

        schedule
      end

      def convert_duration_to_seconds(ical_duration)
        return 0 unless ical_duration

        conversion_rates = { seconds: 1, minutes: 60, hours: 3600, days: 86400, weeks: 604800 }
        seconds = conversion_rates.inject(0) { |sum, (unit, multiplier)| sum + ical_duration.send(unit) * multiplier }
        seconds * (ical_duration.past ? -1 : 1)
      end
    end
  end
end
